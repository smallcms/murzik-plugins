package App::TeleGramma::Plugin::Core::Zhrat;
$App::TeleGramma::Plugin::Core::Zhrat::VERSION = '0.15';
# ABSTRACT: TeleGramma plugin to give Zhrat where necessary

use Mojo::Base 'App::TeleGramma::Plugin::Base';
use App::TeleGramma::BotAction::Listen;
use App::TeleGramma::Constants qw/:const/;

use File::Spec::Functions qw/catfile/;

my $regex = qr/^пр[ао]с[иiі] \s* жра[тц]ь/xi;
#$regex = qr/(a)/i;

sub synopsis {
  "Gives the appropriate response to zhrat"
}

sub default_config {
  my $self = shift;
  return { };
}

sub register {
  my $self = shift;
  my $zhrat_happens = App::TeleGramma::BotAction::Listen->new(
    command  => $regex,
    response => sub { $self->Zhrat(@_) }
  );

  return ($zhrat_happens);
}

sub Zhrat {
  my $self = shift;
  my $msg  = shift;

  return PLUGIN_NO_RESPONSE unless $msg->text;  # don't try to deal with anything but text

  my ($zhratee) = ($msg->text =~ $regex);

  my $result = $zhratee;
  #while (length $result) {
    #last if $result =~ /^[aeiou]/i;
    #$result = substr $result, 1;
  #}

  return PLUGIN_DECLINED if ! length $result;

  #my $Zhrat = "Мяу! Сам ты как $zhratee ". lc $result;
  my $Zhrat = "!дай";

  $self->reply_to($msg, $Zhrat);
  return PLUGIN_RESPONDED;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

App::TeleGramma::Plugin::Core::Zhrat - TeleGramma plugin to give Zhrat where necessary

=head1 VERSION

version 0.15

=head1 AUTHOR

smallcms <smallcms@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2024 by smallcms <smallcms@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
