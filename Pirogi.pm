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

use utf8;
use HTML::Entities;

use File::Spec::Functions qw/catfile/;
use Encode qw(decode_utf8 encode_utf8);

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
    command  => qr/^!дай(?:\s+мне\s+с\s+(.+))?/i,
    response => sub { $self->emit_fortune(@_) }
  );
#  my $fortune_command = App::TeleGramma::BotAction::Listen->new(
#    command  => '!дай',
#    response => sub { $self->emit_fortune(@_) }
#  );
  my $add_fortune_command = App::TeleGramma::BotAction::Listen->new(
    command  => qr/^!(добавь|дадай|dadaj|dodaj)\b/i,
    response => sub { $self->add_fortune(@_) }
  );
  my $stats_command = App::TeleGramma::BotAction::Listen->new(
    command  => '!стат',
    response => sub { $self->emit_stats(@_) }
  );
  my $menu_command = App::TeleGramma::BotAction::Listen->new(
    command  => '!меню',
    response => sub { $self->show_menu(@_) }
  );

  return ($fortune_command, $add_fortune_command, $stats_command, $menu_command);
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

  my $chat_id = $msg->chat->id;
  #my $username = $msg->from->username;

  #reply to user

  my $Forr = '';
  my $Focc = '';
  $Focc = $self->store->hash('counts_'.$chat_id)->{$username};

#my $msgt = $msg->entities->user;
#say "DEBUG: Substring found: $msgt";

  if ($ch =~ /^\-[0-9]+/i) {
    my $g_fortune;
    if ($msg->text =~ /^!дай\sмне\sс\s(.+)/i) {
        my $substr = $1;
        #say "DEBUG: Substring found: $substr";
        $g_fortune = $self->_get_fortune_with_substr($substr);
    } else {
        #say "DEBUG: No substring found";
        $g_fortune = $self->_get_fortune();
    }

    $Forr = "$username " . "Палучы перажог с " . $g_fortune->{text} . " (№" . $g_fortune->{index} . ") ПП:";
    $self->reply_to($msg, $Forr . $Focc, {parse_mode => 'HTML'});
  } else {
    my $g_fortune;
    if ($msg->text =~ /^!дай\sмне\sс\s(.+)/i) {
        my $substr = $1;
        $g_fortune = $self->_get_fortune_with_substr($substr);
    } else {
        $g_fortune = $self->_get_fortune();
    }

    $Forr = "Палучы перажог с " . $g_fortune->{text} . " (№" . $g_fortune->{index} . ") ПП:";
    $self->reply_to($msg, $Forr . $Focc, {parse_mode => 'HTML'});
  }
  #$self->reply_to($msg, $self->_get_fortune());

  # keep some stats, separated by chat and totals

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
  $new_fortune = "$new_fortune";

  # Save the new fortune to the fortune_path file directly
  my $fortune_path = $self->read_config->{fortune_path};
  my $fortune_file = catfile($fortune_path, 'pirogi');

  # Open the file and append the new fortune
  open my $fh, '>>', $fortune_file or die "Could not open file '$fortune_file' for append: $!";
  print $fh encode_utf8($new_fortune."\n");
  close $fh;

  $new_fortune = encode_entities($new_fortune);
  $new_fortune =~ s/&laquo;/«/gi;
  $new_fortune =~ s/&raquo;/»/gi;
  $new_fortune =~ s/&ndash;/–/gi;
  $new_fortune =~ s/&mdash;/—/gi;
  $new_fortune =~ s/&lsquo;/‘/gi;
  $new_fortune =~ s/&rsquo;/’/gi;
  $new_fortune =~ s/&middot;/·/gi;
  $new_fortune =~ s/&micro;/µ/gi;
  $new_fortune =~ s/&Agrave;/À/gi;
  $new_fortune =~ s/&Aacute;/Á/gi;
  $new_fortune =~ s/&Acirc;/Â/gi;
  $new_fortune =~ s/&Atilde;/Ã/gi;
  $new_fortune =~ s/&Auml;/Ä/gi;
  $new_fortune =~ s/&Aring;/Å/gi;
  $new_fortune =~ s/&agrave;/à/gi;
  $new_fortune =~ s/&aacute;/á/gi;
  $new_fortune =~ s/&acirc;/â/gi;
  $new_fortune =~ s/&atilde;/ã/gi;
  $new_fortune =~ s/&auml;/ä/gi;
  $new_fortune =~ s/&aring;/å/gi;
  $new_fortune =~ s/&AElig;/Æ/gi;
  $new_fortune =~ s/&aelig;/æ/gi;
  $new_fortune =~ s/&szlig;/ß/gi;
  $new_fortune =~ s/&Ccedil;/Ç/gi;
  $new_fortune =~ s/&ccedil;/ç/gi;
  $new_fortune =~ s/&Egrave;/È/gi;
  $new_fortune =~ s/&Eacute;/É/gi;
  $new_fortune =~ s/&Ecirc;/Ê/gi;
  $new_fortune =~ s/&Euml;/Ë/gi;
  $new_fortune =~ s/&egrave;/è/gi;
  $new_fortune =~ s/&eacute;/é/gi;
  $new_fortune =~ s/&ecirc;/ê/gi;
  $new_fortune =~ s/&euml;/ë/gi;
  $new_fortune =~ s/&#131;/ƒ/gi;
  $new_fortune =~ s/&Igrave;/Ì/gi;
  $new_fortune =~ s/&Iacute;/Í/gi;
  $new_fortune =~ s/&Icirc;/Î/gi;
  $new_fortune =~ s/&Iuml;/Ï/gi;
  $new_fortune =~ s/&igrave;/ì/gi;
  $new_fortune =~ s/&iacute;/í/gi;
  $new_fortune =~ s/&icirc;/î/gi;
  $new_fortune =~ s/&iuml;/ï/gi;
  $new_fortune =~ s/&Ntilde;/Ñ/gi;
  $new_fortune =~ s/&ntilde;/ñ/gi;
  $new_fortune =~ s/&Ograve;/Ò/gi;
  $new_fortune =~ s/&Oacute;/Ó/gi;
  $new_fortune =~ s/&Ocirc;/Ô/gi;
  $new_fortune =~ s/&Otilde;/Õ/gi;
  $new_fortune =~ s/&Ouml;/Ö/gi;
  $new_fortune =~ s/&ograve;/ò/gi;
  $new_fortune =~ s/&oacute;/ó/gi;
  $new_fortune =~ s/&ocirc;/ô/gi;
  $new_fortune =~ s/&otilde;/õ/gi;
  $new_fortune =~ s/&ouml;/ö/gi;
  $new_fortune =~ s/&Oslash;/Ø/gi;
  $new_fortune =~ s/&oslash;/ø/gi;
  $new_fortune =~ s/&#140;/Œ/gi;
  $new_fortune =~ s/&#156;/œ/gi;
  $new_fortune =~ s/&#138;/Š/gi;
  $new_fortune =~ s/&#154;/š/gi;
  $new_fortune =~ s/&Ugrave;/Ù/gi;
  $new_fortune =~ s/&Uacute;/Ú/gi;
  $new_fortune =~ s/&Ucirc;/Û/gi;
  $new_fortune =~ s/&Uuml;/Ü/gi;
  $new_fortune =~ s/&ugrave;/ù/gi;
  $new_fortune =~ s/&uacute;/ú/gi;
  $new_fortune =~ s/&ucirc;/û/gi;
  $new_fortune =~ s/&uuml;/ü/gi;
  $new_fortune =~ s/&#181;/µ/gi;
  $new_fortune =~ s/&#215;/×/gi;
  $new_fortune =~ s/&Yacute;/Ý/gi;
  $new_fortune =~ s/&#159;/Ÿ/gi;
  $new_fortune =~ s/&yacute;/ý/gi;
  $new_fortune =~ s/&yuml;/ÿ/gi;
  $new_fortune =~ s/&#176;/°/gi;
  $new_fortune =~ s/&#134;/†/gi;
  $new_fortune =~ s/&#135;/‡/gi;
  $new_fortune =~ s/&#177;/±/gi;
  $new_fortune =~ s/&#171;/«/gi;
  $new_fortune =~ s/&#187;/»/gi;
  $new_fortune =~ s/&#191;/¿/gi;
  $new_fortune =~ s/&#161;/¡/gi;
  $new_fortune =~ s/&#183;/·/gi;
  $new_fortune =~ s/&#149;/•/gi;
  $new_fortune =~ s/&#153;/™/gi;
  $new_fortune =~ s/&copy;/©/gi;
  $new_fortune =~ s/&reg;/®/gi;
  $new_fortune =~ s/&#167;/§/gi;
  $new_fortune =~ s/&#182;/¶/gi;
  $new_fortune =~ s/&epsilon;/ε/gi;
  $new_fortune =~ s/&hellip;/…/gi;
  $new_fortune =~ s/&trade;/™/gi;
  $new_fortune =~ s/&deg;/°/gi;
  $new_fortune =~ s/&bull;/•/gi;

  my @responses = (
    "Новэй перажог с $new_fortune довайблен!",
    "Новы пирожог с $new_fortune дабублен!",
    "Новый пердежок с $new_fortune дабавлин!",
    "Nowy pieróg z $new_fortune dadano!"
  );

  my $response = $responses[rand @responses];

  $self->reply_to($msg, $response, {parse_mode => 'HTML'});
  #$self->reply_to($msg, "Новэй перажог с $new_fortune довайблен!", {parse_mode => 'HTML'});

  return PLUGIN_RESPONDED;
}

sub _get_fortune {
    my $self = shift;
    my $path = $self->read_config->{fortune_path};

    opendir(my $dh, $path) || die "can't opendir $path: $!";
    my @files = grep { ! /\.dat$/ && -f catfile($path, $_) } readdir($dh);
    closedir($dh);

    my $file = $files[rand @files];
    open my $fh, '<:raw:encoding(UTF-8)', catfile($path, $file) or die "Can't open $file: $!";
    my $entries = do { local $/; <$fh> };
    close $fh;

    my @entries = split "\n", $entries;
    my $entriesnum = int(rand @entries);
    my $entry = {
        text  => $entries[$entriesnum],
        index => $entriesnum + 1,  # номер строки массива (начиная с 1)
    };

    # Конвертировать символы Unicode в HTML-сущности
    $entry->{text} = encode_entities($entry->{text});

    # Дополнительные замены
    $entry->{text} =~ s/&laquo;/«/gi;
    $entry->{text} =~ s/&raquo;/»/gi;
    $entry->{text} =~ s/&ndash;/–/gi;
    $entry->{text} =~ s/&mdash;/—/gi;
    $entry->{text} =~ s/&lsquo;/‘/gi;
    $entry->{text} =~ s/&rsquo;/’/gi;
    $entry->{text} =~ s/&middot;/·/gi;
    $entry->{text} =~ s/&micro;/µ/gi;
    $entry->{text} =~ s/&Agrave;/À/gi;
    $entry->{text} =~ s/&Aacute;/Á/gi;
    $entry->{text} =~ s/&Acirc;/Â/gi;
    $entry->{text} =~ s/&Atilde;/Ã/gi;
    $entry->{text} =~ s/&Auml;/Ä/gi;
    $entry->{text} =~ s/&Aring;/Å/gi;
    $entry->{text} =~ s/&agrave;/à/gi;
    $entry->{text} =~ s/&aacute;/á/gi;
    $entry->{text} =~ s/&acirc;/â/gi;
    $entry->{text} =~ s/&atilde;/ã/gi;
    $entry->{text} =~ s/&auml;/ä/gi;
    $entry->{text} =~ s/&aring;/å/gi;
    $entry->{text} =~ s/&AElig;/Æ/gi;
    $entry->{text} =~ s/&aelig;/æ/gi;
    $entry->{text} =~ s/&szlig;/ß/gi;
    $entry->{text} =~ s/&Ccedil;/Ç/gi;
    $entry->{text} =~ s/&ccedil;/ç/gi;
    $entry->{text} =~ s/&Egrave;/È/gi;
    $entry->{text} =~ s/&Eacute;/É/gi;
    $entry->{text} =~ s/&Ecirc;/Ê/gi;
    $entry->{text} =~ s/&Euml;/Ë/gi;
    $entry->{text} =~ s/&egrave;/è/gi;
    $entry->{text} =~ s/&eacute;/é/gi;
    $entry->{text} =~ s/&ecirc;/ê/gi;
    $entry->{text} =~ s/&euml;/ë/gi;
    $entry->{text} =~ s/&#131;/ƒ/gi;
    $entry->{text} =~ s/&Igrave;/Ì/gi;
    $entry->{text} =~ s/&Iacute;/Í/gi;
    $entry->{text} =~ s/&Icirc;/Î/gi;
    $entry->{text} =~ s/&Iuml;/Ï/gi;
    $entry->{text} =~ s/&igrave;/ì/gi;
    $entry->{text} =~ s/&iacute;/í/gi;
    $entry->{text} =~ s/&icirc;/î/gi;
    $entry->{text} =~ s/&iuml;/ï/gi;
    $entry->{text} =~ s/&Ntilde;/Ñ/gi;
    $entry->{text} =~ s/&ntilde;/ñ/gi;
    $entry->{text} =~ s/&Ograve;/Ò/gi;
    $entry->{text} =~ s/&Oacute;/Ó/gi;
    $entry->{text} =~ s/&Ocirc;/Ô/gi;
    $entry->{text} =~ s/&Otilde;/Õ/gi;
    $entry->{text} =~ s/&Ouml;/Ö/gi;
    $entry->{text} =~ s/&ograve;/ò/gi;
    $entry->{text} =~ s/&oacute;/ó/gi;
    $entry->{text} =~ s/&ocirc;/ô/gi;
    $entry->{text} =~ s/&otilde;/õ/gi;
    $entry->{text} =~ s/&ouml;/ö/gi;
    $entry->{text} =~ s/&Oslash;/Ø/gi;
    $entry->{text} =~ s/&oslash;/ø/gi;
    $entry->{text} =~ s/&#140;/Œ/gi;
    $entry->{text} =~ s/&#156;/œ/gi;
    $entry->{text} =~ s/&#138;/Š/gi;
    $entry->{text} =~ s/&#154;/š/gi;
    $entry->{text} =~ s/&Ugrave;/Ù/gi;
    $entry->{text} =~ s/&Uacute;/Ú/gi;
    $entry->{text} =~ s/&Ucirc;/Û/gi;
    $entry->{text} =~ s/&Uuml;/Ü/gi;
    $entry->{text} =~ s/&ugrave;/ù/gi;
    $entry->{text} =~ s/&uacute;/ú/gi;
    $entry->{text} =~ s/&ucirc;/û/gi;
    $entry->{text} =~ s/&uuml;/ü/gi;
    $entry->{text} =~ s/&#181;/µ/gi;
    $entry->{text} =~ s/&#215;/×/gi;
    $entry->{text} =~ s/&Yacute;/Ý/gi;
    $entry->{text} =~ s/&#159;/Ÿ/gi;
    $entry->{text} =~ s/&yacute;/ý/gi;
    $entry->{text} =~ s/&yuml;/ÿ/gi;
    $entry->{text} =~ s/&#176;/°/gi;
    $entry->{text} =~ s/&#134;/†/gi;
    $entry->{text} =~ s/&#135;/‡/gi;
    $entry->{text} =~ s/&#177;/±/gi;
    $entry->{text} =~ s/&#171;/«/gi;
    $entry->{text} =~ s/&#187;/»/gi;
    $entry->{text} =~ s/&#191;/¿/gi;
    $entry->{text} =~ s/&#161;/¡/gi;
    $entry->{text} =~ s/&#183;/·/gi;
    $entry->{text} =~ s/&#149;/•/gi;
    $entry->{text} =~ s/&#153;/™/gi;
    $entry->{text} =~ s/&copy;/©/gi;
    $entry->{text} =~ s/&reg;/®/gi;
    $entry->{text} =~ s/&#167;/§/gi;
    $entry->{text} =~ s/&#182;/¶/gi;
    $entry->{text} =~ s/&epsilon;/ε/gi;
    $entry->{text} =~ s/&hellip;/…/gi;
    $entry->{text} =~ s/&trade;/™/gi;
    $entry->{text} =~ s/&deg;/°/gi;
    $entry->{text} =~ s/&bull;/•/gi;

    return $entry;
}

sub _get_fortune_with_substr {
    my ($self, $substr) = @_;
    my $path = $self->read_config->{fortune_path};

    opendir(my $dh, $path) || die "can't opendir $path: $!";
    my @files = grep { ! /\.dat$/ && -f catfile($path, $_) } readdir($dh);
    closedir($dh);

    my @matching_entries;
    my $total_entries = 0;
    foreach my $file (@files) {
        my $file_path = catfile($path, $file);
        open my $fh, '<:raw:encoding(UTF-8)', $file_path or die "Can't open $file_path: $!";
        my $entries = do { local $/; <$fh> };
        close $fh;

        my @entries = split "\n", $entries;
        foreach my $entry (@entries) {
            $total_entries++;
            if ($entry =~ /(\Q$substr\E)/i) {
                my $formatted_entry = {
                    text  => encode_entities($entry),
                    index => $total_entries,
                };

                # Дополнительные замены
                $formatted_entry->{text} =~ s/&laquo;/«/gi;
                $formatted_entry->{text} =~ s/&raquo;/»/gi;
                $formatted_entry->{text} =~ s/&ndash;/–/gi;
                $formatted_entry->{text} =~ s/&mdash;/—/gi;
                $formatted_entry->{text} =~ s/&lsquo;/‘/gi;
                $formatted_entry->{text} =~ s/&rsquo;/’/gi;
                $formatted_entry->{text} =~ s/&middot;/·/gi;
                $formatted_entry->{text} =~ s/&micro;/µ/gi;
                $formatted_entry->{text} =~ s/&Agrave;/À/gi;
                $formatted_entry->{text} =~ s/&Aacute;/Á/gi;
                $formatted_entry->{text} =~ s/&Acirc;/Â/gi;
                $formatted_entry->{text} =~ s/&Atilde;/Ã/gi;
                $formatted_entry->{text} =~ s/&Auml;/Ä/gi;
                $formatted_entry->{text} =~ s/&Aring;/Å/gi;
                $formatted_entry->{text} =~ s/&agrave;/à/gi;
                $formatted_entry->{text} =~ s/&aacute;/á/gi;
                $formatted_entry->{text} =~ s/&acirc;/â/gi;
                $formatted_entry->{text} =~ s/&atilde;/ã/gi;
                $formatted_entry->{text} =~ s/&auml;/ä/gi;
                $formatted_entry->{text} =~ s/&aring;/å/gi;
                $formatted_entry->{text} =~ s/&AElig;/Æ/gi;
                $formatted_entry->{text} =~ s/&aelig;/æ/gi;
                $formatted_entry->{text} =~ s/&szlig;/ß/gi;
                $formatted_entry->{text} =~ s/&Ccedil;/Ç/gi;
                $formatted_entry->{text} =~ s/&ccedil;/ç/gi;
                $formatted_entry->{text} =~ s/&Egrave;/È/gi;
                $formatted_entry->{text} =~ s/&Eacute;/É/gi;
                $formatted_entry->{text} =~ s/&Ecirc;/Ê/gi;
                $formatted_entry->{text} =~ s/&Euml;/Ë/gi;
                $formatted_entry->{text} =~ s/&egrave;/è/gi;
                $formatted_entry->{text} =~ s/&eacute;/é/gi;
                $formatted_entry->{text} =~ s/&ecirc;/ê/gi;
                $formatted_entry->{text} =~ s/&euml;/ë/gi;
                $formatted_entry->{text} =~ s/&#131;/ƒ/gi;
                $formatted_entry->{text} =~ s/&Igrave;/Ì/gi;
                $formatted_entry->{text} =~ s/&Iacute;/Í/gi;
                $formatted_entry->{text} =~ s/&Icirc;/Î/gi;
                $formatted_entry->{text} =~ s/&Iuml;/Ï/gi;
                $formatted_entry->{text} =~ s/&igrave;/ì/gi;
                $formatted_entry->{text} =~ s/&iacute;/í/gi;
                $formatted_entry->{text} =~ s/&icirc;/î/gi;
                $formatted_entry->{text} =~ s/&iuml;/ï/gi;
                $formatted_entry->{text} =~ s/&Ntilde;/Ñ/gi;
                $formatted_entry->{text} =~ s/&ntilde;/ñ/gi;
                $formatted_entry->{text} =~ s/&Ograve;/Ò/gi;
                $formatted_entry->{text} =~ s/&Oacute;/Ó/gi;
                $formatted_entry->{text} =~ s/&Ocirc;/Ô/gi;
                $formatted_entry->{text} =~ s/&Otilde;/Õ/gi;
                $formatted_entry->{text} =~ s/&Ouml;/Ö/gi;
                $formatted_entry->{text} =~ s/&ograve;/ò/gi;
                $formatted_entry->{text} =~ s/&oacute;/ó/gi;
                $formatted_entry->{text} =~ s/&ocirc;/ô/gi;
                $formatted_entry->{text} =~ s/&otilde;/õ/gi;
                $formatted_entry->{text} =~ s/&ouml;/ö/gi;
                $formatted_entry->{text} =~ s/&Oslash;/Ø/gi;
                $formatted_entry->{text} =~ s/&oslash;/ø/gi;
                $formatted_entry->{text} =~ s/&#140;/Œ/gi;
                $formatted_entry->{text} =~ s/&#156;/œ/gi;
                $formatted_entry->{text} =~ s/&#138;/Š/gi;
                $formatted_entry->{text} =~ s/&#154;/š/gi;
                $formatted_entry->{text} =~ s/&Ugrave;/Ù/gi;
                $formatted_entry->{text} =~ s/&Uacute;/Ú/gi;
                $formatted_entry->{text} =~ s/&Ucirc;/Û/gi;
                $formatted_entry->{text} =~ s/&Uuml;/Ü/gi;
                $formatted_entry->{text} =~ s/&ugrave;/ù/gi;
                $formatted_entry->{text} =~ s/&uacute;/ú/gi;
                $formatted_entry->{text} =~ s/&ucirc;/û/gi;
                $formatted_entry->{text} =~ s/&uuml;/ü/gi;
                $formatted_entry->{text} =~ s/&#181;/µ/gi;
                $formatted_entry->{text} =~ s/&#215;/×/gi;
                $formatted_entry->{text} =~ s/&Yacute;/Ý/gi;
                $formatted_entry->{text} =~ s/&#159;/Ÿ/gi;
                $formatted_entry->{text} =~ s/&yacute;/ý/gi;
                $formatted_entry->{text} =~ s/&yuml;/ÿ/gi;
                $formatted_entry->{text} =~ s/&#176;/°/gi;
                $formatted_entry->{text} =~ s/&#134;/†/gi;
                $formatted_entry->{text} =~ s/&#135;/‡/gi;
                $formatted_entry->{text} =~ s/&#177;/±/gi;
                $formatted_entry->{text} =~ s/&#171;/«/gi;
                $formatted_entry->{text} =~ s/&#187;/»/gi;
                $formatted_entry->{text} =~ s/&#191;/¿/gi;
                $formatted_entry->{text} =~ s/&#161;/¡/gi;
                $formatted_entry->{text} =~ s/&#183;/·/gi;
                $formatted_entry->{text} =~ s/&#149;/•/gi;
                $formatted_entry->{text} =~ s/&#153;/™/gi;
                $formatted_entry->{text} =~ s/&copy;/©/gi;
                $formatted_entry->{text} =~ s/&reg;/®/gi;
                $formatted_entry->{text} =~ s/&#167;/§/gi;
                $formatted_entry->{text} =~ s/&#182;/¶/gi;
                $formatted_entry->{text} =~ s/&epsilon;/ε/gi;
                $formatted_entry->{text} =~ s/&hellip;/…/gi;
                $formatted_entry->{text} =~ s/&trade;/™/gi;
                $formatted_entry->{text} =~ s/&deg;/°/gi;
                $formatted_entry->{text} =~ s/&bull;/•/gi;

                push @matching_entries, $formatted_entry;
            }
        }
    }

    if (@matching_entries) {
        my $entriesnum = int(rand @matching_entries);
        return $matching_entries[$entriesnum];
    }

    # Если нет совпадений, возвращаем случайный пирожок
    return $self->_get_fortune();
}

sub show_menu {
    my $self = shift;
    my $msg  = shift;

    my $path = $self->read_config->{fortune_path};

    opendir(my $dh, $path) || die "can't opendir $path: $!";
    my @files = grep { ! /\.dat$/ && -f catfile($path, $_) } readdir($dh);
    closedir($dh);

    my $total_lines = 0;

    foreach my $file (@files) {
        my $file_path = catfile($path, $file);
        open my $fh, '<:encoding(UTF-8)', $file_path or die "Can't open $file_path: $!";
        my $entries = do { local $/; <$fh> };

        my @entries = split "\n", $entries;
        $total_lines += scalar @entries;  # Подсчет строк в каждом файле
        close $fh;
    }

    my $menu_text = "У нас имеются нехуевое меню ($total_lines шт):\n";
    my $entry_number = 1;

    foreach my $file (@files) {
        my $file_path = catfile($path, $file);
        open my $fh, '<:raw:encoding(UTF-8)', $file_path or die "Can't open $file_path: $!";
        binmode $fh, ':raw:encoding(UTF-8)';
        my $entries = do { local $/; <$fh> };

        my @entries = split "\n", $entries;
        foreach my $entry (@entries) {
            $entry = encode_entities($entry);
            $entry =~ s/&laquo;/«/gi;
            $entry =~ s/&raquo;/»/gi;
            $entry =~ s/&ndash;/–/gi;
            $entry =~ s/&mdash;/—/gi;
            $entry =~ s/&lsquo;/‘/gi;
            $entry =~ s/&rsquo;/’/gi;
            $entry =~ s/&middot;/·/gi;
            $entry =~ s/&micro;/µ/gi;
            $entry =~ s/&Agrave;/À/gi;
            $entry =~ s/&Aacute;/Á/gi;
            $entry =~ s/&Acirc;/Â/gi;
            $entry =~ s/&Atilde;/Ã/gi;
            $entry =~ s/&Auml;/Ä/gi;
            $entry =~ s/&Aring;/Å/gi;
            $entry =~ s/&agrave;/à/gi;
            $entry =~ s/&aacute;/á/gi;
            $entry =~ s/&acirc;/â/gi;
            $entry =~ s/&atilde;/ã/gi;
            $entry =~ s/&auml;/ä/gi;
            $entry =~ s/&aring;/å/gi;
            $entry =~ s/&AElig;/Æ/gi;
            $entry =~ s/&aelig;/æ/gi;
            $entry =~ s/&szlig;/ß/gi;
            $entry =~ s/&Ccedil;/Ç/gi;
            $entry =~ s/&ccedil;/ç/gi;
            $entry =~ s/&Egrave;/È/gi;
            $entry =~ s/&Eacute;/É/gi;
            $entry =~ s/&Ecirc;/Ê/gi;
            $entry =~ s/&Euml;/Ë/gi;
            $entry =~ s/&egrave;/è/gi;
            $entry =~ s/&eacute;/é/gi;
            $entry =~ s/&ecirc;/ê/gi;
            $entry =~ s/&euml;/ë/gi;
            $entry =~ s/&#131;/ƒ/gi;
            $entry =~ s/&Igrave;/Ì/gi;
            $entry =~ s/&Iacute;/Í/gi;
            $entry =~ s/&Icirc;/Î/gi;
            $entry =~ s/&Iuml;/Ï/gi;
            $entry =~ s/&igrave;/ì/gi;
            $entry =~ s/&iacute;/í/gi;
            $entry =~ s/&icirc;/î/gi;
            $entry =~ s/&iuml;/ï/gi;
            $entry =~ s/&Ntilde;/Ñ/gi;
            $entry =~ s/&ntilde;/ñ/gi;
            $entry =~ s/&Ograve;/Ò/gi;
            $entry =~ s/&Oacute;/Ó/gi;
            $entry =~ s/&Ocirc;/Ô/gi;
            $entry =~ s/&Otilde;/Õ/gi;
            $entry =~ s/&Ouml;/Ö/gi;
            $entry =~ s/&ograve;/ò/gi;
            $entry =~ s/&oacute;/ó/gi;
            $entry =~ s/&ocirc;/ô/gi;
            $entry =~ s/&otilde;/õ/gi;
            $entry =~ s/&ouml;/ö/gi;
            $entry =~ s/&Oslash;/Ø/gi;
            $entry =~ s/&oslash;/ø/gi;
            $entry =~ s/&#140;/Œ/gi;
            $entry =~ s/&#156;/œ/gi;
            $entry =~ s/&#138;/Š/gi;
            $entry =~ s/&#154;/š/gi;
            $entry =~ s/&Ugrave;/Ù/gi;
            $entry =~ s/&Uacute;/Ú/gi;
            $entry =~ s/&Ucirc;/Û/gi;
            $entry =~ s/&Uuml;/Ü/gi;
            $entry =~ s/&ugrave;/ù/gi;
            $entry =~ s/&uacute;/ú/gi;
            $entry =~ s/&ucirc;/û/gi;
            $entry =~ s/&uuml;/ü/gi;
            $entry =~ s/&#181;/µ/gi;
            $entry =~ s/&#215;/×/gi;
            $entry =~ s/&Yacute;/Ý/gi;
            $entry =~ s/&#159;/Ÿ/gi;
            $entry =~ s/&yacute;/ý/gi;
            $entry =~ s/&yuml;/ÿ/gi;
            $entry =~ s/&#176;/°/gi;
            $entry =~ s/&#134;/†/gi;
            $entry =~ s/&#135;/‡/gi;
            $entry =~ s/&#177;/±/gi;
            $entry =~ s/&#171;/«/gi;
            $entry =~ s/&#187;/»/gi;
            $entry =~ s/&#191;/¿/gi;
            $entry =~ s/&#161;/¡/gi;
            $entry =~ s/&#183;/·/gi;
            $entry =~ s/&#149;/•/gi;
            $entry =~ s/&#153;/™/gi;
            $entry =~ s/&copy;/©/gi;
            $entry =~ s/&reg;/®/gi;
            $entry =~ s/&#167;/§/gi;
            $entry =~ s/&#182;/¶/gi;
            $entry =~ s/&epsilon;/ε/gi;
            $entry =~ s/&hellip;/…/gi;
            $entry =~ s/&trade;/™/gi;
            $entry =~ s/&deg;/°/gi;
            $entry =~ s/&bull;/•/gi;

            my $formatted_entry = "$entry_number. $entry\n";
            if (length($menu_text) + length($formatted_entry) > 5000) {
                #say "DEBUG: Sending chunk:\n", dumper($menu_text);
                $self->reply_to($msg, $menu_text, {parse_mode => 'HTML', disable_web_page_preview => 'true'});
                $menu_text = $formatted_entry;
            } else {
                $menu_text .= $formatted_entry;
            }
            $entry_number++;
        }
        close $fh;
    }

    $self->reply_to($msg, $menu_text, {parse_mode => 'HTML'}) if $menu_text;

    return PLUGIN_RESPONDED;
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
