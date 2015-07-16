#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/time.h>

#include <math.h>
#include <assert.h>
#include <errno.h>

#ifdef WIN32
#include <windows.h>
#include <mmsystem.h>
#include <mmreg.h>
#else
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <pthread.h>
#include <signal.h>
#include <unistd.h>
#define SOCKET int
#endif

#include <jack/jack.h>
#include "circular_buffer.h"
#include "ir.h"
#include "VistaThreadEventARM.h"

#define DEFAULT_CIRCULAR_BUFFER_SIZE (1024*20)
#define RECV_BUFFER_SIZE (15000)
#define CHANNELS 2

#define UDP_PKG_FLAG_IR_SYNC_MASTER 1
#define UDP_PKG_FLAG_IR_SYNC_CLIENT 2

#define SYNC_OFFSET 200

CircularBuffer<StereoFloatSample> circularBuffer;
bool g_silence;
bool g_isRunning;

unsigned long g_skippedSamples;
unsigned long g_lostPackages;

in_addr g_streamerIp;

VistaThreadEvent g_evSync;
struct SyncData {
	int packetIndex;
	long bufferSize;
	bool master;
};
SyncData g_syncData;

jack_port_t *out_ports[CHANNELS];

#ifdef WIN32
#define THREAD_FUNC DWORD WINAPI
#else
#define THREAD_FUNC void *
#endif

THREAD_FUNC UdpRecvThread (void *Arg);
THREAD_FUNC IRThread(void *Arg);

void received_sync_package(unsigned int index, int ringBufferSize, bool master);

void sayIAmHere(SOCKET soc, bool notGoodby);
SOCKET initUDPBroadcast();
SOCKET initUDPHeartbeat();
void heartbeat(SOCKET soc);

jack_client_t *g_jackClient;

static void signal_handler(int sig)
{
	jack_client_t *client = g_jackClient;
	if(client != NULL) {
		fprintf(stderr, "JACKInterface: Closing client ...\n");
		jack_client_close(client);
	}
	fprintf(stderr, "JACKInterface: signal received, exiting ...\n");
	g_isRunning = false;
}

unsigned long sampleCounter = 0;

long get_system_timing() {
	long jackTime;
	struct timeval tv;

	gettimeofday (&tv, NULL);
	jackTime = (long) tv.tv_sec * 1000000 + (long) tv.tv_usec;
	return jackTime;
}

static int JackProcess (jack_nframes_t nframes, void *arg)
{
	jack_default_audio_sample_t *out1 = (jack_default_audio_sample_t *)jack_port_get_buffer (out_ports[0], nframes);
	jack_default_audio_sample_t *out2 = (jack_default_audio_sample_t *)jack_port_get_buffer (out_ports[1], nframes);

	bool bufferUnderrun = circularBuffer.GetNum() < nframes;
	if(bufferUnderrun) {
		usleep((nframes-2) * 1000000 / SAMPLE_RATE);
		bufferUnderrun = (circularBuffer.GetNum() < nframes);
		
		if(!bufferUnderrun)
			printf("delayed processing prevented underrun!\n");
	}
			
	for(int i = 0; i < nframes; i++)
    {
		// todo: instead of returning 0 here, should wait 1 period for new data!		
		if(bufferUnderrun && circularBuffer.isEmpty())
		{
			*out1++ = 0.0f;
			*out2++ = 0.0f;
			if(!g_silence) {
				g_silence = true;
				printf("SILENCE!\n");
			}
		} else {
			StereoFloatSample sample = circularBuffer.Read();
			
			/*
			// if left is NAN, its a SYNC package!
			if(sample.left == NAN) {
				int packetIndex = *((int*)&sample.right);
			}
			*/
			
			*out1++ = sample.left;
			*out2++ = sample.right;

			if(g_silence) {
				g_silence = false;
				printf("NO SILENCE!\n");
			}
		}
	}
	
	/*
	processCounter++;
	if(processCounter >= 50) {
		int processedFrames = processCounter * nframes;
		long t = get_system_timing();
		
		int sampleRate = (int)((long)processedFrames * 1000000L / (long)(t - processLastMeasure));
		
		processLastMeasure = t;
		processCounter = 0;
		
		printf("T: %d Sample Rate: %d; processed: %d \n", processLastMeasure, sampleRate, processedFrames);
	}
*/
	sampleCounter += nframes;
	

	return 0;
}

void jackShutdown (void *arg)
{
	if(arg != NULL)
		delete arg;
	fprintf(stderr, "jackShutdown: exiting ...\n");
	g_isRunning = false;
}

void jackMsg(const char *msg)
{
	fprintf(stderr,"%s\n",msg);
}


void initJack()
{
	fprintf(stderr, "Init Jack ...\n");
	
	const char *client_name = "udp-receiver";
	const char *server_name = NULL;
	jack_options_t options = JackNoStartServer; // JackNoStartServer; // 
	jack_status_t status;

	jack_set_error_function(jackMsg);
	jack_set_info_function(jackMsg);

	g_jackClient = jack_client_open (client_name, options, &status);

	if (g_jackClient == NULL) {
		fprintf (stderr, "jack_client_open() failed, "
				"status = 0x%2.0x\n", status);
		if (status & JackServerFailed) {
			fprintf (stderr, "Unable to connect to JACK server\n");
		}
		exit (1);
	}

	if (status & JackServerStarted) {
		fprintf (stderr, "JACK server started\n");
	}
	if (status & JackNameNotUnique) {
		client_name = jack_get_client_name(g_jackClient);
		fprintf (stderr, "unique name `%s' assigned\n", client_name);
	}

	/* tell the JACK server to call `process()' whenever
		there is work to be done.
	*/


	jack_set_process_callback (g_jackClient, JackProcess, NULL);

	jack_on_shutdown (g_jackClient, jackShutdown, 0);

	
	char port_name[12];

	for(int i = 0; i < CHANNELS; i++) {		
		sprintf(port_name, "out%00d", i);
		out_ports[i] = jack_port_register (g_jackClient, port_name, JACK_DEFAULT_AUDIO_TYPE, JackPortIsOutput, 0);
		if (out_ports[i] == NULL) {
			fprintf(stderr, "no more JACK ports available\n");
			exit (1);
		}
	}
	
	
	if (jack_activate (g_jackClient)) {
		fprintf(stderr, "could not activate client!\n");
		exit (1);
	}

	/* install a signal handler to properly quits jack client */
#ifdef WIN32
	signal(SIGINT, signal_handler);
	signal(SIGABRT, signal_handler);
	signal(SIGTERM, signal_handler);
#else
	signal(SIGQUIT, signal_handler);
	signal(SIGTERM, signal_handler);
	signal(SIGHUP, signal_handler);
	signal(SIGINT, signal_handler);
#endif
}

void initUDPReceiver()
{
	fprintf(stderr, "Init UDP ...\n");
	
#ifdef WIN32
    HANDLE UdpRecvThreadHandle;
    DWORD UdpRecvThreadId;

      // Init Network
    UdpRecvThreadHandle = CreateThread (NULL, 0, UdpRecvThread, NULL, 0, &UdpRecvThreadId );
#else
	pthread_t udpThread;
	int rc;
    rc = pthread_create(&udpThread, NULL, UdpRecvThread, (void *)NULL);
    assert(0 == rc);
#endif
}

void initIR()
{
	fprintf(stderr, "Init IR ...\n");

	g_evSync.ResetThisEvent();
	
	ir_init();
	
#ifdef WIN32
    HANDLE IRThreadHandle;
    DWORD IRThreadId;

      // Init Network
    IRThreadHandle = CreateThread (NULL, 0, IRThread, NULL, 0, &IRThreadId );
#else
	pthread_t irThread;
	int rc;
    rc = pthread_create(&irThread, NULL, IRThread, (void *)NULL);
    assert(0 == rc);
#endif
}

void finalizeJack()
{
}

void finalizeUDPReceiver()
{
#ifndef WIN32
	pthread_exit(NULL);
#endif	
}

/*******************************************************************/
int main(int argc, char **argv)
{
    int i;
	printf("START\n");
	
	/*
	char cmd[100];
	sprintf(cmd, "chrt -p 40 -f %d", getpid());
	system(cmd);
	*/
	
	g_silence = true;
	g_isRunning = true;
	g_skippedSamples = 0;
	g_lostPackages = 0;
	
	circularBuffer.Init((argc < 2 || (i=atoi(argv[1])) <= 0) ? DEFAULT_CIRCULAR_BUFFER_SIZE : i);
	    
  	SOCKET broadcast = initUDPBroadcast();
	if(broadcast < 0)
		return 1;
		
	SOCKET feedback = initUDPHeartbeat();
		
	initJack();
	initUDPReceiver();
	initIR();
	
	usleep(100*1000);

	// fill ring buffer to 50%
	StereoFloatSample sample;
	sample.left = sample.right = 0.0f;
	while(circularBuffer.GetUsagePercentage() < 25.0f)
		circularBuffer.Write(sample);

	while(g_isRunning) {
#ifdef WIN32
			Sleep(500);
#else
			usleep(1000 * 1000);
#endif
		if(circularBuffer.GetUsagePercentage() > 0.1f) {
			printf("LOST: %u\tSKIP: %u\t", g_lostPackages, g_skippedSamples); 
			circularBuffer.PrintUsageBar();
		}
		
		printf("Sample Rate: %d\n", sampleCounter);
		sampleCounter = 0;
		
		if(g_silence) {
			// while silence, broadcast that I'm here
			sayIAmHere(broadcast, true);
		} else {
			heartbeat(feedback);
		}
	}
	
	printf("Saying goodbye...\n");
	// unregister
	sayIAmHere(broadcast, false);
	
	finalizeUDPReceiver();
	finalizeJack();

	return 0;
}


void print_last_errno()
{
	switch(errno ) {
		case EADDRINUSE: printf("EADDRINUSE\n"); break;
		case EADDRNOTAVAIL: printf("EADDRNOTAVAIL\n"); break;
		case EBADF: printf("EBADF\n"); break;
		case ECONNABORTED: printf("ECONNABORTED\n"); break;
		case EINVAL: printf("EINVAL\n"); break;
		case EIO: printf("EIO\n"); break;
		case ENOBUFS: printf("ENOBUFS\n"); break;
		case ENOPROTOOPT: printf("ENOPROTOOPT\n"); break;
		case ENOTCONN: printf("ENOTCONN\n"); break;
		case ENOTSOCK: printf("ENOTSOCK\n"); break;
		case EPERM: printf("EPERM\n"); break;
		case ETOOMANYREFS: printf("ETOOMANYREFS\n"); break;
		case EUNATCH: printf("EUNATCH\n"); break;
		default: printf("UNKNOWN\n"); break;
	}	
}


SOCKET initUDPBroadcast()
{
	printf("Init Broadcast socket...\n");
	SOCKET soc = socket(AF_INET,SOCK_DGRAM,0);
	if(soc < 0) {
		printf("Error: could not create broadcast socket!\n");
		return -1;
	}
	int yes = 1;
	// allow broadcast
	int rv = setsockopt(soc, SOL_SOCKET, SO_BROADCAST, &yes, sizeof(yes));
	if(rv < 0) {
		printf("Error: could not set broadcast socket options!\n");
		print_last_errno();
		return -1;
	}
		
	return soc;
}


SOCKET initUDPHeartbeat()
{
	printf("Init Broadcast socket...\n");
	SOCKET soc = socket(AF_INET,SOCK_DGRAM,0);
	if(soc < 0) {
		printf("Error: could not create broadcast socket!\n");
		return -1;
	}
		
	return soc;
}

void heartbeat(SOCKET soc)
{
	char data[100];
	
	strcpy(data, "HEARTBEAT");
	data[9] = '\0';
	
	int i = 10;
	*reinterpret_cast<unsigned long*>(&data[i+=sizeof(unsigned long)]) = g_lostPackages;
	*reinterpret_cast<unsigned long*>(&data[i+=sizeof(unsigned long)]) = g_skippedSamples;
	
    struct sockaddr_in s;
    memset(&s, 0, sizeof(struct sockaddr_in));
    s.sin_family = AF_INET;
    s.sin_port = (in_port_t)htons(6788);
    s.sin_addr = g_streamerIp;
	
	int r = sendto(soc, data, i, 0, (struct sockaddr*)&s, sizeof(struct sockaddr_in));
	if(r != i) {
		printf("Could not send heartbeat!\n");
	}
}

void sayIAmHere(SOCKET soc, bool notGoodby)
{
	char data[500];
	
	char hostname[32];
	hostname[31] = '\0';
	gethostname(hostname, 31);
	
	if(notGoodby)
		strcpy(data, "REGISTER_DEVICE");
	else
		strcpy(data, "UNREGISTER_DEVICE");
	data[15] = '\0';
	strcpy(&data[16], hostname);
	
	
    struct sockaddr_in s;
    memset(&s, 0, sizeof(struct sockaddr_in));
    s.sin_family = AF_INET;
    s.sin_port = (in_port_t)htons(6788);
    s.sin_addr.s_addr = htonl(INADDR_BROADCAST);
	
	int r = sendto(soc, data, 16+32, 0, (struct sockaddr*)&s, sizeof(struct sockaddr_in));

	if(r != 16+32) {
		printf("Broadcasting %s failed (%d) Still trying 10.0.0.255.\n",data,r);
	}
	
	//printf("Broadcasting hello failed. Trying to send to 10.0.0.255...\n");
	inet_aton("10.0.0.255", &s.sin_addr);
	r = sendto(soc, data, 16+32, 0, (struct sockaddr*)&s, sizeof(struct sockaddr_in));	

	printf("I AM HERE %s! %d\n", hostname, r);
}

THREAD_FUNC UdpRecvThread (void *Arg)
{
#ifdef WIN32
  WSADATA wsaData;
  SOCKET localfd;
#else
	int localfd;
#endif

  //char *host = "225.3.19.154";

  // TODO SO_PRIORITY 
  
  struct sockaddr_in local;   // UDP Empfaenger IPv4 Adress und Port Struktur
  int len;
  int rv;
  unsigned long expectedPacketIdx = 0;
  bool firstPacket = true;

  bool drainBuffer = false;

 
#ifdef WIN32
  rv = SetThreadPriority (GetCurrentThread (), THREAD_PRIORITY_TIME_CRITICAL);
	//assert(0 == rv);
  /* MS-Windows spezielle Socket Initialisierung */
  rv = WSAStartup(MAKEWORD(2, 2), &wsaData);
//  winexit_if(rv != 0, hWindow, "WSAStartup failed");
#else

#endif


  localfd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP); // Socket Filedeskriptor anlegen
  //winexit_if(localfd < 0, hWindow, "socket failed");
  
	const int prio = 7;
	int opt = prio << 5;
	rv = setsockopt(localfd, SOL_IP, IP_TOS, &opt, sizeof(opt));
	if(rv < 0) {
		printf("Error: could not set socket IP_TOS priority!\n");
		print_last_errno();
	}

	int so_priority = prio;
	rv = setsockopt(localfd, SOL_SOCKET, SO_PRIORITY, &so_priority, sizeof(so_priority));
	if(rv < 0) {
		printf("Error: could not set socket SO_PRIORITY!\n");
		print_last_errno();
	}
	printf("Socket priority set!\n");
	
  memset(&local, 0, sizeof(local)); // local mit 0 vollschreiben
  local.sin_family = AF_INET; 
  local.sin_port = htons(6789);
  local.sin_addr.s_addr = INADDR_ANY;

//	struct hostent *he = (host != NULL) ? gethostbyname(host) : NULL;
//	if((he != NULL)) local.sin_addr =  *((struct in_addr *) he->h_addr) ;

  // local Server IPv4 Adresse eintragen
  rv = bind(localfd, (struct sockaddr *) &local, sizeof(local));
  //winexit_if(rv < 0, hWindow, "bind failed");

  char lastPackage[RECV_BUFFER_SIZE];
  int lastLen = 0;

  while(g_isRunning) {                                // Endlosschleife
    struct sockaddr_in remote;  // UDP Sender IPv4 Adress und Port Struktur
    int i,j;
#ifndef WIN32
	unsigned
#endif
		int addr_len;
    char recvBuffer[RECV_BUFFER_SIZE];
	unsigned int packetIndex;
	char flags;

    addr_len = sizeof(remote);
	len = recvfrom(localfd, (char*)recvBuffer, sizeof(recvBuffer), 0, (struct sockaddr *) &remote, &addr_len);
	
	if(len < 8)
		continue;
		
	g_streamerIp = remote.sin_addr;

	packetIndex = *((unsigned int*)&recvBuffer[0]);
	i = sizeof(packetIndex);
	
	if(firstPacket) {
		expectedPacketIdx = packetIndex;
		firstPacket = false;
	} else if(packetIndex != expectedPacketIdx) {
		g_lostPackages += fabsf(packetIndex - expectedPacketIdx);
		if(packetIndex == (expectedPacketIdx+1)) {
			printf("LOST single package\n");
		} else
			printf("received unexpected package (got: %u  exp: %u)\n", packetIndex, expectedPacketIdx);
		expectedPacketIdx = packetIndex;
	}
	expectedPacketIdx++;

	flags = recvBuffer[i];
	i += 4; // skip flags and header stuff
	
	if(flags == UDP_PKG_FLAG_IR_SYNC_MASTER || flags == UDP_PKG_FLAG_IR_SYNC_CLIENT) {
		received_sync_package(packetIndex, circularBuffer.GetNum(), (flags == UDP_PKG_FLAG_IR_SYNC_MASTER));
	}

	float bufUse = circularBuffer.GetUsagePercentage();

	if(!drainBuffer && bufUse > 70.0f)
		drainBuffer = true;
	else if(drainBuffer && bufUse < 30.0f)
		drainBuffer = false;

	for(; i < len; i+=sizeof(StereoFloatSample)) {
		StereoFloatSample sample = *((StereoFloatSample*)&recvBuffer[i]);

		if(fabs(sample.left) > 1.0f || fabs(sample.right) > 1.0f)
		{
			printf("received invalid sample (L=%4.2f R=%4.2f)\n", sample.left, sample.right);
		}

		if(drainBuffer)
		{
			if(i % (100 - (int)bufUse) == 0) {
				//printf("sample skipping.\n");
				g_skippedSamples++;
				continue;
			}
		}
		
		// write return 1 if buffer is full!
		g_skippedSamples += circularBuffer.Write(sample);
	}

	// skip single sample 
	if(bufUse > 60.0f) {
		circularBuffer.Read();
		g_skippedSamples++;
	}

	memcpy(lastPackage, recvBuffer, len);
	lastLen = len;
  }
}





void received_sync_package(unsigned int index, int ringBufferSize, bool master)
{
	printf("Received Sync Package %u, while buffer is %d samples\n", index, ringBufferSize);
	g_syncData.packetIndex = index;
	g_syncData.bufferSize = ringBufferSize;
	g_evSync.SignalEvent();
}


THREAD_FUNC IRThread (void *Arg)
{
	while(g_isRunning)
	{
		g_evSync.WaitForEvent(true);
		g_evSync.ResetThisEvent();
		
		if(g_syncData.master) {
			long delay = g_syncData.bufferSize * 1000000L / (long)SAMPLE_RATE; // predict the time in useconds when the first sample of this packet will be played.
			printf("SYNC_DELAY by %d\n",(int)delay);
			usleep(delay); // send IR sync exactly when packet will start playing		
			ir_send_sync(g_syncData.packetIndex % 16);
		} else {
			timespec t_first_recv;
			int packetIndex = ir_read_sync(&t_first_recv);
			if(packetIndex > 0 && packetIndex == (g_syncData.packetIndex % 16)) {
				
			}
		}
	}
}
