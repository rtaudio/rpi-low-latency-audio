#pragma once

int ir_init();
int ir_send_sync(char idx);
int ir_read_sync(timespec *t_first);