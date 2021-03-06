GOOF----LE-4-2.0�      ]  4       hE      ] g  guile�	 �	g  define-module*�	 �	 �	g  ice-9�	g  stack-catch�	 �		g  filenameS�	
f  ice-9/stack-catch.scm�	g  importsS�	g  
save-stack�	 �	 �	 �	g  exportsS�	 �	g  set-current-module�	 �	 �	g  catch�	g  throw�C 5      h�  a   ]4	
5 4 >  "  G    h(   }   - 1 3 4	>  "  G   @     u       g  key
			# g  args			#  g  filenamef  ice-9/stack-catch.scm�
	+		��	
	-	��	#	.	�� 			#
   C        h   �  ] 6  �      g  key
		 g  thunk		 g  handler			  g  filenamef  ice-9/stack-catch.scm�
	
��		(	�� 			  g  nameg  stack-catch�g  documentationf Like @code{catch}, invoke @var{thunk} in the dynamic context of
@var{handler} for exceptions matching @var{key}, but also save the
current stack state in the @var{the-last-stack} fluid, for the purpose
of debugging or re-throwing of an error.  If thunk throws to the
symbol @var{key}, then @var{handler} is invoked this way:

@example
 (handler key args ...)
@end example

@var{key} is a symbol or #t.

@var{thunk} takes no arguments.  If @var{thunk} returns normally, that
is the return value of @code{catch}.

Handler is invoked outside the scope of its own @code{catch}.  If
@var{handler} again throws to the same key, a new handler from further
up the call chain is invoked.

If the key is @code{#t}, then a throw to @emph{any} symbol will match
this call to @code{catch}.� CRC    Y       g  m
		,  g  filenamef  ice-9/stack-catch.scm�		
���	
�� 	�
   C6 