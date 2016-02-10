# Paragraph.pm: handle paragraph text.
#
# Copyright 2010, 2011, 2012, 2013 Free Software Foundation, Inc.
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License,
# or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
# 
# Original author: Patrice Dumas <pertusus@free.fr>

# this module has nothing Texinfo specific.  In contrast with existing
# modules Text::Wrap, Text::Format, it keeps a state of the paragraph 
# and wait for text to be feed.

package Texinfo::Convert::Paragraph;

use 5.006;
use strict;

use Unicode::EastAsianWidth;
use Carp qw(cluck);

# initialize a paragraph object.
sub new($;$)
{
  my $class = shift;
  my $conf = shift;
  my $self = {'max' => 72, 'indent_length' => 0, 'counter' => 0, 
              'word_counter' => 0, 'space' => '', 'frenchspacing' => 0,
              'lines_counter' => 0, 'end_line_count' => 0};
  if (defined($conf)) {
    foreach my $key (keys(%$conf)) {
      $self->{$key} = $conf->{$key};
    }
  }
  bless $self, $class;
}

# for debugging
sub dump($)
{
  my $self = shift;
  my $word = 'UNDEF';
  my $underlying = '';
  if (defined($self->{'word'})) {
    $word = $self->{'word'};
    if ($self->{'word'} ne $self->{'underlying_word'}) {
      $underlying = ", underlying_word: $self->{'underlying_word'},";
    }
  }
  my $end_sentence = 'UNDEF';
  $end_sentence = $self->{'end_sentence'} if (defined($self->{'end_sentence'}));
  print STDERR "para ($self->{'counter'}+$self->{'word_counter'}) word: $word, space `$self->{'space'}'${underlying} end_sentence: $end_sentence\n"; 
}

sub _cut_line($)
{
  my $paragraph = shift;
  return '' if ($paragraph->{'ignore_columns'});
  return _end_line($paragraph);
}

sub end_line_count($)
{
  my $paragraph = shift;
  return $paragraph->{'end_line_count'};
}

sub end_line($)
{
  my $paragraph = shift;
  $paragraph->{'end_line_count'} = 0;
  return _end_line($paragraph);
}

# end a line.
sub _end_line($)
{
  my $paragraph = shift;
  $paragraph->{'counter'} = 0;
  $paragraph->{'space'} = '';
  if (defined($paragraph->{'indent_length_next'})) {
    $paragraph->{'indent_length'} = $paragraph->{'indent_length_next'};
    delete $paragraph->{'indent_length_next'};        
  }
  $paragraph->{'lines_counter'}++;
  $paragraph->{'end_line_count'}++;
  print STDERR "END_LINE\n" if ($paragraph->{'DEBUG'});
  return "\n";
}

sub get_pending($)
{
  my $paragraph = shift;
  my $result = '';
  if ($paragraph->{'space'}) {
    $result .= $paragraph->{'space'};
  }
  if (defined($paragraph->{'word'})) {
    $result .= $paragraph->{'word'};
  }
  return $result;
}

sub add_pending_word($;$)
{
  my $paragraph = shift;
  my $add_spaces = shift;
  $paragraph->{'end_line_count'} = 0;
  return _add_pending_word($paragraph, $add_spaces);
}

# put a pending word and spaces in the result string.
sub _add_pending_word($;$)
{
  my $paragraph = shift;
  my $add_spaces = shift;
  my $result = '';

  if (defined($paragraph->{'word'}) or $add_spaces) {
    if ($paragraph->{'indent_length'} > $paragraph->{'counter'}) {
      $result .= ' ' x ($paragraph->{'indent_length'} - $paragraph->{'counter'});
      $paragraph->{'counter'} = $paragraph->{'indent_length'};
      print STDERR "INDENT($paragraph->{'counter'}+$paragraph->{'word_counter'})\n" 
                   if ($paragraph->{'DEBUG'});
    } elsif ($paragraph->{'space'}) {
      $result .= $paragraph->{'space'};
      $paragraph->{'counter'} += length($paragraph->{'space'});
      print STDERR "ADD_SPACES($paragraph->{'counter'}+$paragraph->{'word_counter'})\n" 
         if ($paragraph->{'DEBUG'});
      
    }
    if (defined($paragraph->{'word'})) {
      $result .= $paragraph->{'word'};
      $paragraph->{'counter'} += $paragraph->{'word_counter'};
      print STDERR "ADD_WORD[$paragraph->{'word'}]+$paragraph->{'word_counter'} ($paragraph->{'counter'})\n"
        if ($paragraph->{'DEBUG'});
      $paragraph->{'word'} = undef;
      $paragraph->{'underlying_word'} = undef;
      $paragraph->{'word_counter'} = 0;
    }
    $paragraph->{'space'} = '';
  }
  return $result;
}

# end a paragraph
sub end($)
{
  my $paragraph = shift;
  $paragraph->{'end_line_count'} = 0;
  print STDERR "PARA END\n" if ($paragraph->{'DEBUG'});
  my $result = _add_pending_word($paragraph);
  if ($paragraph->{'counter'} != 0) {
    $result .= "\n"; 
    $paragraph->{'lines_counter'}++;
    $paragraph->{'end_line_count'}++;
  }
  return $result;
}

sub add_next($;$$$$)
{
  my $paragraph = shift;
  my $word = shift;
  my $space = shift;
  my $end_sentence = shift;
  my $transparent = shift;
  $paragraph->{'end_line_count'} = 0;
  return _add_next($paragraph, $word, undef, $space, $end_sentence, 
                   $transparent);
}

# add a word and/or spaces and end of sentence.
sub _add_next($;$$$$$$)
{
  my $paragraph = $_[0];
  my $word = $_[1];
  my $space = $_[3];
  my $end_sentence = $_[4];
  my $transparent = $_[5];
  my $result = '';

  if (defined($word)) {
    my $underlying_word = $_[2];
    my $newlines_impossible = $_[6];
    $underlying_word = $word if (!defined($underlying_word));

    if (!defined($paragraph->{'word'})) {
      $paragraph->{'word'} = '';
      $paragraph->{'underlying_word'} = '';
      if ($paragraph->{'end_sentence'} 
           and $paragraph->{'end_sentence'} > 0
           and !$paragraph->{'frenchspacing'}
           and $paragraph->{'counter'} != 0 and $paragraph->{'space'}) {
        # do not to double space if there are leading spaces in word
        if ($word !~ /^\s/) {
          #$paragraph->{'space'} = '  ';
          $paragraph->{'space'} .= ' ' x (2 - length($paragraph->{'space'}));
        }
        delete $paragraph->{'end_sentence'};
      }
    }
    
    $paragraph->{'word'} .= $word;
    $paragraph->{'underlying_word'} .= $underlying_word unless($transparent);
    if (!$newlines_impossible and $word =~ /\n/) {
      $result .= $paragraph->{'space'};
      $paragraph->{'space'} = '';
      $result .= $paragraph->{'word'};
      _end_line($paragraph);
      $paragraph->{'word_counter'} = 0;
      $paragraph->{'word'} = undef;
      $paragraph->{'underlying_word'} = undef;
    } else {
      $paragraph->{'word_counter'} += length($word);
    }
    if ($paragraph->{'DEBUG'}) {
      my $para_word = 'UNDEF';;
      if (defined($paragraph->{'word'})) {
        $para_word = $paragraph->{'word'};
      }
      my $para_underlying_word = 'UNDEF';;
      if (defined($paragraph->{'underlying_word'})) {
        $para_underlying_word = $paragraph->{'word'};
      }

      print STDERR "WORD+ $word -> $para_word\n";
      print STDERR "UNDERLYING_WORD+ $underlying_word -> $para_underlying_word\n";
    }
    # The $paragraph->{'counter'} != 0 is here to avoid having an
    # additional line output when the text is longer than the max.
    if ($paragraph->{'counter'} != 0 and 
        $paragraph->{'counter'} + $paragraph->{'word_counter'} + 
           length($paragraph->{'space'}) > $paragraph->{'max'}) {
      $result .= _cut_line($paragraph);
    }
  }
  if (defined($space)) {
    if ($paragraph->{'protect_spaces'}) {
      $result .= _add_text($paragraph, $space);
    } else {
      $result .= _add_pending_word($paragraph);
      $paragraph->{'space'} = $space;
      if ($paragraph->{'counter'} + length($paragraph->{'space'}) 
                      > $paragraph->{'max'}) {
        $result .= _cut_line($paragraph);
      }
    }
  }
  if (defined($end_sentence)) {
    $paragraph->{'end_sentence'} = $end_sentence;
  }
  return $result;
}

sub add_underlying_text($$)
{
  my $paragraph = shift;
  my $underlying_text = shift;
  if (defined($underlying_text)) {
    $paragraph->{'underlying_word'} = ''
       if (!defined($paragraph->{'underlying_word'}));
    $paragraph->{'underlying_word'} .= $underlying_text;
  }
}

sub inhibit_end_sentence($)
{
  my $paragraph = shift;
  $paragraph->{'end_sentence'} = 0;
}

sub set_space_protection($$;$$$)
{
  my $paragraph = shift;
  my $space_protection = shift;
  my $ignore_columns = shift;
  my $keep_end_lines = shift;
  my $frenchspacing = shift;
  $paragraph->{'protect_spaces'} = $space_protection 
    if defined($space_protection);
  $paragraph->{'ignore_columns'} = $ignore_columns
    if defined($ignore_columns);
  $paragraph->{'keep_end_lines'} = $keep_end_lines
    if defined($keep_end_lines);
  if (!$paragraph->{'frenchspacing'} and $frenchspacing
    and $paragraph->{'end_sentence'} and $paragraph->{'counter'} != 0 
    and $paragraph->{'space'} and !defined($paragraph->{'word'})) {
    $paragraph->{'space'} .= ' ' x (2 - length($paragraph->{'space'}));
    print STDERR "SWITCH frenchspacing end sentence space\n" 
       if ($paragraph->{'DEBUG'});
    delete $paragraph->{'end_sentence'};
  }
  $paragraph->{'frenchspacing'} = $frenchspacing
    if defined($frenchspacing);
  # begin a word, to have something even if empty
  if ($space_protection) {
    _add_next($paragraph, '');
  }
  return '';
}

my $end_sentence_character = quotemeta('.?!');
my $after_punctuation_characters = quotemeta('"\')]');

# wrap a text.
sub add_text($$;$)
{
  my $paragraph = shift;
  my $text = shift;
  my $underlying_text = shift;
  $paragraph->{'end_line_count'} = 0;
  my $result = '';

  my $protect_spaces_flag = $paragraph->{'protect_spaces'};

  my @segments = split
/([^\S\x{202f}\x{00a0}]+)|(\p{InFullwidth})|((?:[^\s\p{InFullwidth}]|[\x{202f}\x{00a0}])+)/,
    $text;

  # Check now if a newline exists anywhere in the string to
  # try to eliminate regex checks later.
  my $newline_possible_flag = ($text =~ /\n/);

  my $debug_flag = $paragraph->{'DEBUG'};
  while (@segments) {
    # $empty_segment should be an empty string; the other variables
    # here were recognized as field separators by splice.
    my ($empty_segment, $spaces, $fullwidth_segment, $added_word)
     = splice (@segments, 0, 4);

    if ($debug_flag) {
      my $word = 'UNDEF';
      $word = $paragraph->{'word'} if (defined($paragraph->{'word'}));
      print STDERR "p ($paragraph->{'counter'}+$paragraph->{'word_counter'}) s `"._print_escaped_spaces($paragraph->{'space'})."', w `$word'\n";
      #print STDERR "TEXT: "._print_escaped_spaces($text)."|\n"
    }
    # \x{202f}\x{00a0} are non breaking spaces
    if (defined $spaces) {
      $underlying_text =~ s/^([^\S\x{202f}\x{00a0}]+)//
        if defined($underlying_text);
      print STDERR "SPACES($paragraph->{'counter'}) `"._print_escaped_spaces($spaces)."'\n" if $debug_flag;
      #my $added_word = $paragraph->{'word'};
      if ($protect_spaces_flag) {
        $paragraph->{'word'} .= $spaces;
        $paragraph->{'underlying_word'} .= $spaces;
        $paragraph->{'word_counter'} += length($spaces);
        #$paragraph->{'space'} .= $spaces;
        if ($paragraph->{'word'} =~ s/\n/ /g 
           and !$paragraph->{'frenchspacing'} 
           and $paragraph->{'end_sentence'}
           and $paragraph->{'end_sentence'} > 0) {
          $paragraph->{'word'} =~ /(\s*)$/;
          if (length($1) < 2) {
            #$paragraph->{'word'} =~ s/(\s*)$/  /;
            #$paragraph->{'underlying_word'} =~ s/(\s*)$/  /;
            #my $removed = $1;
            #$paragraph->{'word_counter'} += length('  ') - length($removed);
            my $added = ' ' x (2 - length($1));
            $paragraph->{'word'} .= $added;
            $paragraph->{'word'} =~ /(\s*)$/;
            my $end_spaces = $1;
            $paragraph->{'underlying_word'} =~ s/(\s*)$/$end_spaces/;
            $paragraph->{'word_counter'} += length($added);
          }
        }
        # The $paragraph->{'counter'} != 0 is here to avoid having an
        # additional line output when the text is longer than the max.
        if ($paragraph->{'counter'} != 0 and 
            $paragraph->{'counter'} + $paragraph->{'word_counter'} + 
               length($paragraph->{'space'}) > $paragraph->{'max'}) {
          $result .= _cut_line($paragraph);
        }
      } else {
        $result .= _add_pending_word($paragraph);
        if ($paragraph->{'counter'} != 0) {
          if ($paragraph->{'end_sentence'} 
              and $paragraph->{'end_sentence'} > 0
              and !$paragraph->{'frenchspacing'}) {
            if (length($paragraph->{'space'}) >= 1 or length($spaces) > 1) {
              # more than one space, we can make sure tht there are only 
              # 2 spaces
              my $all_spaces = substr($paragraph->{'space'} . $spaces, 0, 2);
              $all_spaces =~ s/[\n\r]/ /g;
              $all_spaces .= ' ' x (2 - length($all_spaces));
              $paragraph->{'space'} = $all_spaces;
              delete $paragraph->{'end_sentence'};
            } else {
              # if there is only one space, we let it accumulate
              my $new_space = $spaces;
              $new_space =~ s/^[\n\r]/ /;
              $paragraph->{'space'} = $new_space;
            }
          } else {
            $paragraph->{'space'} = substr($spaces, 0, 1);
            if ($paragraph->{'space'} eq "\n"
                or $paragraph->{'space'} eq "\r") {
              $paragraph->{'space'} = " ";
            }
          }
        }
      }
      #print STDERR "delete END_SENTENCE($paragraph->{'end_sentence'}): spaces\n" 
      #  if (defined($paragraph->{'end_sentence'}) and $paragraph->{'DEBUG'});
      #delete $paragraph->{'end_sentence'};
      if ($paragraph->{'counter'} + length($paragraph->{'space'}) 
                      > $paragraph->{'max'}) {
        $result .= _cut_line($paragraph);
      }
      if ($newline_possible_flag
          and $paragraph->{'keep_end_lines'} and $spaces =~ /\n/) {
        $result .= _end_line($paragraph);
      }
    } elsif (defined $added_word) {
      my $underlying_added_word;
      if (defined($underlying_text)) {
        $underlying_text =~ s/^(([^\s\p{InFullwidth}]|[\x{202f}\x{00a0}])+)//;
        $underlying_added_word = $1;
      } else {
        $underlying_added_word = $added_word;
      }

      $result .= _add_next($paragraph, $added_word, $underlying_added_word,
                           undef, undef, undef, !$newline_possible_flag);

      # now check if it is considered as an end of sentence
      if (defined($paragraph->{'end_sentence'})
          and $underlying_added_word =~ /^[$after_punctuation_characters]*$/o) {
        # do nothing in the case of a continuation of after_punctuation_characters
      } elsif ($paragraph->{'underlying_word'} =~ /[$end_sentence_character][$after_punctuation_characters]*$/o
           and $paragraph->{'underlying_word'} !~ /[[:upper:]][$end_sentence_character$after_punctuation_characters]*$/o) {
        if ($paragraph->{'frenchspacing'}) {
          $paragraph->{'end_sentence'} = -1;
        } else {
          $paragraph->{'end_sentence'} = 1;
        }
        print STDERR "END_SENTENCE\n" if ($paragraph->{'DEBUG'});
      } else {
        delete $paragraph->{'end_sentence'};
        print STDERR "delete END_SENTENCE($paragraph->{'end_sentence'}): text\n" 
          if (defined($paragraph->{'end_sentence'}) and $paragraph->{'DEBUG'});
      }
    } elsif (defined $fullwidth_segment) {
      my $underlying_added;
      if (defined($underlying_text)) {
        $underlying_text =~ s/^(\p{InFullwidth})//;
        $underlying_added = $1;
      } else {
        $underlying_added = $fullwidth_segment;
      }
      
      print STDERR "EAST_ASIAN\n" if ($paragraph->{'DEBUG'});
      if (!defined($paragraph->{'word'})) {
        $paragraph->{'word'} = '';
        $paragraph->{'underlying_word'} = '';
      }
      $paragraph->{'word'} .= $fullwidth_segment;
      $paragraph->{'underlying_word'} .= $underlying_added; 
      $paragraph->{'word_counter'} += 2;
      if ($paragraph->{'counter'} != 0 and
          $paragraph->{'counter'} + $paragraph->{'word_counter'} 
                               > $paragraph->{'max'}) {
        $result .= _cut_line($paragraph);
      }
      $result .= _add_pending_word($paragraph);
      delete $paragraph->{'end_sentence'};
      $paragraph->{'space'} = '';
    }
  }
  return $result;
}

# for debug
sub _print_escaped_spaces($)
{
  my $spaces = shift;
  my $result = '';
  foreach my $pos (0 .. length($spaces)-1) {
    my $char = substr($spaces, $pos, 1);
    if ($char eq ' ') {
      $result .= $char;
    } elsif ($char =~ /[\f\n]/) {
      $char =~ s/\f/\\f/;
      $char =~ s/\n/\\n/;
      $result .= $char;
    } elsif ($char =~ /\s/) {
      if (ord($char) <= hex(0xFFFF)) {
        $result .= '\x'.sprintf("%04x",ord($char));
      } else {
        $result .= '\x'.sprintf("%06x",ord($char));
      }
    } else {
      $result .= $char;
    }
  }
  return $result;
}

1;
