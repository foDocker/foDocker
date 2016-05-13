#!/usr/bin/env perl
use Mojolicious::Lite;
use Mojo::JSON qw/from_json/;
use Mojo::UserAgent;

helper "endpoints" => sub {
  state $endpoints ||= {};
};

helper "scripts" => sub {
  state $scripts ||= {};
};

helper create_endpoint => sub {
  my $c     = shift;
  my $name  = shift;
  my $data  = shift;

  $c->endpoints->{$name} = $data;
};

helper ua => sub {
      state $ua ||= Mojo::UserAgent->new;
};

helper create_script => sub {
  my $c     = shift;
  my $name  = shift;
  my $data  = shift;

  $c->scripts->{$name} = $data;
  Mojo::IOLoop->interval(10 => sub {
    my $ret = qx|$data->{code}|;
    if($ret) {
      my $scale = from_json $ret;
      $ua->post("http://composeapi/$data->{service}/run" => json => $scale)
    }
  });
};

get "/inform/:rule" => sub {
  my $c     = shift;
  my $name  = shift;

  my $rule = $c->endpoints($name);
};

post "/rule/:rule" => sub {
  my $c     = shift;
  my $name  = $c->param("rule");
  my $rule  = $c->req->json;

  if($rule->{type} eq "ENDPOINT") {
    $c->create_endpoint($name, $rule);
  } elsif($rule->{type} eq "SCRIPT") {
    $c->create_script($name, $rule);
  }
};
