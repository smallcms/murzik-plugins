package App::TeleGramma::Plugin::Core::Pirogi;
$App::TeleGramma::Plugin::Core::Pirogi::VERSION = '0.15';
# ABSTRACT: TeleGramma plugin to emit pirogi

use strict;
use warnings;
use v5.10.0;
use POSIX;

use Mojo::Base 'App::TeleGramma::Plugin::Base';
use App::TeleGramma::BotAction::Listen;
use App::TeleGramma::Constants qw/:const/;

use File::Spec::Functions qw/catfile/;
use Mojo::File;
#use Mojo::Util 'decode';
#use utf8;
use Encode qw(decode_utf8 encode_utf8);
#use Encode qw(decode encode);

sub synopsis {
  "Responds with pirogi"
}

sub default_config {
  my $self = shift;
  return { fortune_path => "/home/murzik/.telegramma/plugindata/plugin-Core-Pirogi" };
}

sub register {
  my $self = shift;

  # sanity checks
  my $fp = $self->read_config->{fortune_path};
  die "fortune_path '$fp' does not exist or is not a directory - check your config\n"
    unless (-d $fp);

  my $fortune_command = App::TeleGramma::BotAction::Listen->new(
    command  => '!дай',
    response => sub { $self->emit_fortune(@_) }
  );
  my $add_fortune_command = App::TeleGramma::BotAction::Listen->new(
    command  => qr/^!(добавь|дадай|dadaj|dodaj)\b/i,
    response => sub { $self->add_fortune(@_) }
  );
  my $stats_command = App::TeleGramma::BotAction::Listen->new(
    command  => '!стат',
    response => sub { $self->emit_stats(@_) }
  );

  return ($fortune_command, $add_fortune_command, $stats_command);
}

sub emit_fortune {
  my $self = shift;
  my $msg  = shift;

  my $ch=$msg->chat->id;
  my $username;
  if ($msg->from) {
    $username = $msg->from->first_name;
    if ($msg->from->last_name) {
      $username = $msg->from->first_name . ' ' . $msg->from->last_name;
    }
    $username = '<a href="tg://user?id=' . $msg->from->id . '">' . $username . '</a>';
  } else {
      $username = "гамнюк";
  }

  #reply to user

  my $Forr = '';
  my $Focc = '';
  $Focc = $self->store->hash('totals')->{total_fortunes};
  if ($ch =~ /^\-[0-9]+/i) {
    $Forr = "$username ".$self->_get_fortune();
    $self->reply_to($msg, $Forr . $Focc, {parse_mode => 'HTML'});
    } else {
        $Forr = "".$self->_get_fortune();
        $self->reply_to($msg, $Forr . $Focc);
    }
  #$self->reply_to($msg, $self->_get_fortune());

  # keep some stats, separated by chat and totals
  my $chat_id = $msg->chat->id;
  #my $username = $msg->from->username;

  $self->store->hash('counts_'.$chat_id)->{$username}++;
  $self->store->hash('totals')->{total_fortunes}++;
  $self->store->save_all;

  return PLUGIN_RESPONDED;
}

sub emit_stats {
  my $self = shift;
  my $msg  = shift;

  my $chat_id = $msg->chat->id;
  my $res;

  foreach my $username ( keys %{ $self->store->hash('counts_'.$chat_id) }) {
    $res .= "$username палучыл " . $self->store->hash('counts_'.$chat_id)->{$username} . " перашков\n";
  }

  $res .= "фсево раздал " . ($self->store->hash('totals')->{total_fortunes} || 0);

  #reply to user
  $self->reply_to($msg, $res, {parse_mode => 'HTML'});

  return PLUGIN_RESPONDED;
}

sub add_fortune {
  my $self = shift;
  my $msg  = shift;

  # Check if the user has the right permissions to add a fortune
  # For example, you might want to check if the user is an admin

  #my $new_fortune = $msg->text =~ s/^!добавь\s*//r; # Extract the fortune text
  my $new_fortune = $msg->text =~ s/^!(добавь|дадай|dodaj|dadaj)\s*//ir;
  #$new_fortune = "с $new_fortune" if ($new_fortune =~ /^(с\s+)?/i); # Add "с " if not present
  #$new_fortune = "с $new_fortune" unless ($new_fortune =~ /^с\s+/i);
  $new_fortune =~ s/^(с\s+|c\s+|з\s+|z\s+|со\s+|са\s+)//i;
  $new_fortune = "с $new_fortune";

  # Save the new fortune to the fortune_path file directly
  my $fortune_path = $self->read_config->{fortune_path};
  my $fortune_file = catfile($fortune_path, 'pirogi');
  #Mojo::File->new($fortune_file)->append(encode('UTF-8', $new_fortune."\n"));
  #Mojo::File->new($fortune_file)->append(encode_utf8($new_fortune."\n"));

  # Open the file and append the new fortune
  open my $fh, '>>', $fortune_file or die "Could not open file '$fortune_file' for append: $!";
  print $fh encode_utf8($new_fortune."\n");
  close $fh;

  $self->reply_to($msg, "Новэй перажог $new_fortune дабавлин!", {parse_mode => 'HTML'});

  return PLUGIN_RESPONDED;
}


sub _get_fortune {
  my $self = shift;
  my $path = $self->read_config->{fortune_path};

  opendir (my $dh, $path) || die "can't opendir $path: $!";
  my @files = grep { ! /.dat$/ && -f catfile($path, $_) } readdir($dh);
  closedir($dh);

  my $file = $files[rand @files];
  my $entries1 = Mojo::File->new(catfile($path, $file))->slurp;
  #my $entries = decode 'UTF-8', $entries1;
  my $entries = decode_utf8($entries1);

  my @entries = split "\n", $entries;
  #my $entriesnum = sprintf "%.0f",(rand @entries);
  my $entriesnum = floor(rand @entries);
  #my $entry = 'Палучы перажог '.$entries[$entriesnum].'!!! ПП:'.( $entriesnum + 1 );
  my $entry = 'Палучы перажог '.$entries[$entriesnum].'!!! ПП:';

  return $entry;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

App::TeleGramma::Plugin::Core::Pirogi - TeleGramma plugin to emit pirogi

=head1 VERSION

version 0.15

=head1 AUTHOR

smallcms <smallcms@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2024 by smallcms <smallcms@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
