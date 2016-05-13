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
  $c->app->log->info("create_endpoint: ", $c->dumper($c->endpoints));
};

helper ua => sub {
      state $ua ||= Mojo::UserAgent->new;
};

helper create_script => sub {
  my $c     = shift;
  my $name  = shift;
  my $data  = shift;

  $c->scripts->{$name} = $data;
  Mojo::IOLoop->recurring(10 => sub {
    my $ret = qx|$data->{code}|;
    if($ret) {
      my $scale = from_json $ret;
      $c->ua->post("http://composeapi/$data->{service}/run" => json => $scale)
    }
  });
};

get "/inform/:rule/:value" => sub {
  my $c     = shift;
  my $stack = $c->param("rule");
  my $value = $c->param("value");

  my $rule = $c->endpoints($stack)->{$stack};
  $c->app->log->info("_______endpoint: ", $c->dumper($c->endpoints));

  $c->app->log->info("value: $value", "rule: ", $c->app->dumper($rule), "endpoints: ", $c->dumper($c->endpoints($rule)));
  if(exists $rule->{$value}) {
      my $data = $rule->{$value};
      $c->app->log->info("scalling: ", $c->dumper($data->{scale}));
      my $res = $c->ua->post("http://composeapi:3000/$stack/run" => json => $data->{scale})->res;
      if($res->error) {
        $c->app->log->error($res->error->{message});
      } else {
        $c->app->log->info("OK");
      }
  } else {
    $c->app->log->info("nao existe");
  }
  $c->render(json => {ok => \1})
};

post "/rule/:rule" => sub {
  my $c     = shift;
  my $name  = $c->param("rule");
  my $rule  = $c->req->json;
  $c->app->log->info($c->app->dumper($rule));

  if($rule->{type} eq "ENDPOINT") {
    $c->create_endpoint($name, $rule);
  } elsif($rule->{type} eq "SCRIPT") {
    $c->create_script($name, $rule);
  }
  $c->render(json => {ok => \1})
};

app->start;
