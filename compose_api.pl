#!/usr/bin/env perl
use Mojolicious::Lite;
use File::Path qw/rmtree/;

helper instances => sub {
  state $instances ||= {};
};

get '/:stack' => sub {
	my $c = shift;
	my $stack = $c->param("stack");
	#$c->render("./$stack/docker-compose.yml");
	my $static = Mojolicious::Static->new( paths => [ "./$stack/" ] );

	$static->serve($c, "docker-compose.yml");
	$c->rendered;
};

post '/:stack' => sub {
	my $c = shift;
	die "no file" unless $c->param("file");
	my $stack = $c->param("stack");
	mkdir "./$stack";
	$c->param("file")->move_to("./$stack/docker-compose.yml");
	$c->render(json => {ok => \1});
};

del '/:stack' => sub {
	my $c = shift;
	my $stack = $c->param("stack");
	rmtree "./$stack";
	$c->render(json => {ok => \1});
};

get '/:stack/run' => sub {
	my $c = shift;
	my $stack = $c->param("stack");
	my $ret = qx{cd ./$stack && docker-compose ps};
	$c->render(text => $ret);
};

post '/:stack/run' => sub {
	my $c = shift;
	my $stack = $c->param("stack");
	my $ret = qx{cd ./$stack && docker-compose up -d 2>&1};
	my $body = $c->req->json;
	if(defined $body) {
                my %tmp;
                my @keys    = keys %$body;
                my $scales = join " ", map {
                  my $instances = $body->{$_};
                  if($instances =~  /^\+(\d+)$/) {
                    $c->instances->{$_} = $instances = ($c->instances->{$_} // 1) + $1;
                  } elsif($instances =~  /^-(\d+)$/) {
                    $c->instances->{$_} = $instances = ($c->instances->{$_} // 1) - $1;
                  } elsif($instances =~  /^\*(\d+)$/) {
                    $c->instances->{$_} = $instances = ($c->instances->{$_} // 1) * $1;
                  } elsif($instances =~  /^\/(\d+)$/) {
                    $c->instances->{$_} = $instances = ($c->instances->{$_} // 1) / $1;
                  }
                  "$_=$instances"
                } keys %$body;
		my $ret .= qx{cd ./$stack && docker-compose scale $scales 2>&1};
	}
	$c->render(json => $ret);
};

del '/:stack/run' => sub {
	my $c = shift;
	my $stack = $c->param("stack");
	my $ret = qx{cd ./$stack && docker-compose down 2>&1};
	$c->render(json => $ret);
};

app->start;
