package App::TeleGramma::Plugin::Core::Hailo;
$App::TeleGramma::Plugin::Core::Hailo::VERSION = '0.02';
# ABSTRACT: TeleGramma plugin to talk with Hailo engine

use strict;
use warnings;
use utf8;
use v5.10.0;
use Hailo;

use HTML::Entities;
use Mojo::Base 'App::TeleGramma::Plugin::Base';
use App::TeleGramma::BotAction::Listen;
use App::TeleGramma::Constants qw/:const/;

use File::Spec::Functions qw/catfile/;

binmode(STDIN, ":encoding(utf8)");

sub synopsis {
  "Gives the appropriate response from Hailo engine"
}

sub default_config {
  my $self = shift;
  return {
    enable       => 1,
    storage_class => 'SQLite',
    brain_path   => "/home/user/bot/brain.sqlite",
  };
}

sub register {
  my $self = shift;
  my $hailo_happens = App::TeleGramma::BotAction::ListenAll->new(
    response => sub { $self->hailo(@_) }
  );

  return ($hailo_happens);
}


sub hailo {

  my $hailo = Hailo->new;

  my $self = shift;
  my $msg  = shift;

  # sanity checks
  my $enable = $self->read_config->{enable};
  return PLUGIN_NO_RESPONSE unless $enable;

  my $storage_class = $self->read_config->{storage_class};
  my $brain_path    = $self->read_config->{brain_path};

  # Check storage_class
  die "Invalid storage_class '$storage_class'. Valid values are Pg, mysql, or SQLite.\n"
    unless $storage_class =~ /^(Pg|mysql|SQLite)$/;

  # Check brain_path if it is specified
  if ($brain_path) {
    die "Brain file '$brain_path' does not exist.\n" unless -e $brain_path;
  }

  $hailo->storage_class($storage_class);
  $hailo->brain($brain_path);

  return PLUGIN_NO_RESPONSE unless $msg->text;  # don't try to deal with anything but text

  my $username;
  if ($msg->from) {
    $username = $msg->from->first_name;
    if ($msg->from->last_name) {
      $username = $msg->from->first_name . ' ' . $msg->from->last_name;
      }
    $username = '<a href="tg://user?id=' . $msg->from->id . '">' . $username . '</a>';
  }
  else {
    $username = "гамнюк";
  }

  my $regex = qr/^(котэ|кот|мурзик|\@murzikby_bot)[\s,:]+(.*)/xi;
  my ($hailomsg) = ($msg->text =~ $regex);
  my $result = $hailomsg;

  my $text = $msg->text;
  $text =~ s/^(котэ|кот|мурзик|\@murzikby_bot)[\s,:]+//gi;

  # Check if $text starts with "!"
  if ($text =~ /^\s*!/) {
    return PLUGIN_DECLINED;
  }

  # learn from users
  $hailo->learn($text);

  my $ch=$msg->chat->id;
  if ($ch =~ /^\-[0-9]+/i) {
  return PLUGIN_DECLINED if ! length $result;
  }

  #reply to user
  binmode STDOUT, ":utf8";
  my $hailoreply=$hailo->reply($text);

  my $Hai = '';
  if ($ch =~ /^\-[0-9]+/i) {
    $hailoreply = encode_entities($hailoreply);
    $hailoreply =~ s/&laquo;/«/gi;
    $hailoreply =~ s/&raquo;/»/gi;
    $hailoreply =~ s/&ndash;/–/gi;
    $hailoreply =~ s/&mdash;/—/gi;
    $hailoreply =~ s/&lsquo;/‘/gi;
    $hailoreply =~ s/&rsquo;/’/gi;
    $hailoreply =~ s/&middot;/·/gi;
    $hailoreply =~ s/&micro;/µ/gi;
    $hailoreply =~ s/&Agrave;/À/gi;
    $hailoreply =~ s/&Aacute;/Á/gi;
    $hailoreply =~ s/&Acirc;/Â/gi;
    $hailoreply =~ s/&Atilde;/Ã/gi;
    $hailoreply =~ s/&Auml;/Ä/gi;
    $hailoreply =~ s/&Aring;/Å/gi;
    $hailoreply =~ s/&agrave;/à/gi;
    $hailoreply =~ s/&aacute;/á/gi;
    $hailoreply =~ s/&acirc;/â/gi;
    $hailoreply =~ s/&atilde;/ã/gi;
    $hailoreply =~ s/&auml;/ä/gi;
    $hailoreply =~ s/&aring;/å/gi;
    $hailoreply =~ s/&AElig;/Æ/gi;
    $hailoreply =~ s/&aelig;/æ/gi;
    $hailoreply =~ s/&szlig;/ß/gi;
    $hailoreply =~ s/&Ccedil;/Ç/gi;
    $hailoreply =~ s/&ccedil;/ç/gi;
    $hailoreply =~ s/&Egrave;/È/gi;
    $hailoreply =~ s/&Eacute;/É/gi;
    $hailoreply =~ s/&Ecirc;/Ê/gi;
    $hailoreply =~ s/&Euml;/Ë/gi;
    $hailoreply =~ s/&egrave;/è/gi;
    $hailoreply =~ s/&eacute;/é/gi;
    $hailoreply =~ s/&ecirc;/ê/gi;
    $hailoreply =~ s/&euml;/ë/gi;
    $hailoreply =~ s/&#131;/ƒ/gi;
    $hailoreply =~ s/&Igrave;/Ì/gi;
    $hailoreply =~ s/&Iacute;/Í/gi;
    $hailoreply =~ s/&Icirc;/Î/gi;
    $hailoreply =~ s/&Iuml;/Ï/gi;
    $hailoreply =~ s/&igrave;/ì/gi;
    $hailoreply =~ s/&iacute;/í/gi;
    $hailoreply =~ s/&icirc;/î/gi;
    $hailoreply =~ s/&iuml;/ï/gi;
    $hailoreply =~ s/&Ntilde;/Ñ/gi;
    $hailoreply =~ s/&ntilde;/ñ/gi;
    $hailoreply =~ s/&Ograve;/Ò/gi;
    $hailoreply =~ s/&Oacute;/Ó/gi;
    $hailoreply =~ s/&Ocirc;/Ô/gi;
    $hailoreply =~ s/&Otilde;/Õ/gi;
    $hailoreply =~ s/&Ouml;/Ö/gi;
    $hailoreply =~ s/&ograve;/ò/gi;
    $hailoreply =~ s/&oacute;/ó/gi;
    $hailoreply =~ s/&ocirc;/ô/gi;
    $hailoreply =~ s/&otilde;/õ/gi;
    $hailoreply =~ s/&ouml;/ö/gi;
    $hailoreply =~ s/&Oslash;/Ø/gi;
    $hailoreply =~ s/&oslash;/ø/gi;
    $hailoreply =~ s/&#140;/Œ/gi;
    $hailoreply =~ s/&#156;/œ/gi;
    $hailoreply =~ s/&#138;/Š/gi;
    $hailoreply =~ s/&#154;/š/gi;
    $hailoreply =~ s/&Ugrave;/Ù/gi;
    $hailoreply =~ s/&Uacute;/Ú/gi;
    $hailoreply =~ s/&Ucirc;/Û/gi;
    $hailoreply =~ s/&Uuml;/Ü/gi;
    $hailoreply =~ s/&ugrave;/ù/gi;
    $hailoreply =~ s/&uacute;/ú/gi;
    $hailoreply =~ s/&ucirc;/û/gi;
    $hailoreply =~ s/&uuml;/ü/gi;
    $hailoreply =~ s/&#181;/µ/gi;
    $hailoreply =~ s/&#215;/×/gi;
    $hailoreply =~ s/&Yacute;/Ý/gi;
    $hailoreply =~ s/&#159;/Ÿ/gi;
    $hailoreply =~ s/&yacute;/ý/gi;
    $hailoreply =~ s/&yuml;/ÿ/gi;
    $hailoreply =~ s/&#176;/°/gi;
    $hailoreply =~ s/&#134;/†/gi;
    $hailoreply =~ s/&#135;/‡/gi;
    $hailoreply =~ s/&lt;/</gi;
    $hailoreply =~ s/&gt;/>/gi;
    $hailoreply =~ s/&#177;/±/gi;
    $hailoreply =~ s/&#171;/«/gi;
    $hailoreply =~ s/&#187;/»/gi;
    $hailoreply =~ s/&#191;/¿/gi;
    $hailoreply =~ s/&#161;/¡/gi;
    $hailoreply =~ s/&#183;/·/gi;
    $hailoreply =~ s/&#149;/•/gi;
    $hailoreply =~ s/&#153;/™/gi;
    $hailoreply =~ s/&copy;/©/gi;
    $hailoreply =~ s/&reg;/®/gi;
    $hailoreply =~ s/&#167;/§/gi;
    $hailoreply =~ s/&#182;/¶/gi;
    $hailoreply =~ s/&epsilon;/ε/gi;
    $hailoreply =~ s/&hellip;/…/gi;
    $hailoreply =~ s/&trade;/™/gi;
    $Hai = "$username $hailoreply";
    $self->reply_to($msg, $Hai, {parse_mode => 'HTML'});
  } else {
    $Hai = "$hailoreply";
    $self->reply_to($msg, $Hai);
  }

  #$self->reply_to($msg, $Hai);
  return PLUGIN_RESPONDED;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

App::TeleGramma::Plugin::Core::Hailo - TeleGramma plugin to talk with Hailo engine

=head1 VERSION

version 0.02

=head1 AUTHOR

smallcms <smallcms@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2019-2024 by smallcms <smallcms@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
