package App::TeleGramma::Plugin::Core::Atruta;
$App::TeleGramma::Plugin::Core::Atruta::VERSION = '0.14';
# ABSTRACT: TeleGramma plugin to give Atruta where necessary

use Mojo::Base 'App::TeleGramma::Plugin::Base';
use App::TeleGramma::BotAction::Listen;
use App::TeleGramma::Constants qw/:const/;

use File::Spec::Functions qw/catfile/;

my $regex = qr/^пр[ао]с[иiі] \s* атруту/xi;
#$regex = qr/(a)/i;

sub synopsis {
  "Gives the appropriate response to Atruta"
}

sub default_config {
  my $self = shift;
  return { };
}

sub register {
  my $self = shift;
  my $atrutas_happens = App::TeleGramma::BotAction::Listen->new(
    command  => $regex,
    response => sub { $self->Atruta(@_) }
  );

  return ($atrutas_happens);
}

sub Atruta {
  my $self = shift;
  my $msg  = shift;

  return PLUGIN_NO_RESPONSE unless $msg->text;  # don't try to deal with anything but text

  my ($atrutaee) = ($msg->text =~ $regex);

  my $result = $atrutaee;
  #while (length $result) {
    #last if $result =~ /^[aeiou]/i;
    #$result = substr $result, 1;
  #}

  return PLUGIN_DECLINED if ! length $result;

  #my $Atruta = "Мяу! Сам ты как $atrutaee ". lc $result;
  my $Atruta = "!атрута";

  $self->reply_to($msg, $Atruta);
  return PLUGIN_RESPONDED;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

App::TeleGramma::Plugin::Core::Atruta - TeleGramma plugin to give Atruta where necessary

=head1 VERSION

version 0.14

=head1 AUTHOR

Justin Hawkins <justin@hawkins.id.au>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2019 by Justin Hawkins <justin@eatmorecode.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
