#!/usr/bin/env perl
use Mojolicious::Lite;
use File::Path qw/rmtree/;
use Git::Class;

helper instances => sub {
	state $instances //= {};
};

helper git => sub {
	state $git //= Git::Class::Cmd->new;
};

#get '/:stack/git' => sub {
#	my $c = shift;
#	my $stack = $c->param("stack");
#	my $static = Mojolicious::Static->new( paths => [ "./$stack/" ] );
#
#	$static->serve($c, "docker-compose.yml");
#	$c->rendered;
#};

post '/:stack/git' => sub {
	my $c = shift;
	die "no git repo" unless $c->param("git");
	my $repo	= $c->param("git");
	my $stack	= $c->param("stack");
	my $wd;
	if(-f "./$stack") {
		$wd = Git::Class::Worktree->new( path => "./$stack/" );
		$wd->pull;
	} else {
		$wd = $c->git->clone($repo, $stack);
	} 
	$c->render(json => {ok => \1});
};

del '/:stack/git' => sub {
	my $c = shift;
	my $stack = $c->param("stack");
	rmtree "./$stack";
	$c->render(json => {ok => \1});
};

get '/:stack/file' => sub {
	my $c = shift;
	my $stack = $c->param("stack");
	#$c->render("./$stack/docker-compose.yml");
	my $static = Mojolicious::Static->new( paths => [ "./$stack/" ] );

	$static->serve($c, "docker-compose.yml");
	$c->rendered;
};

post '/:stack/file' => sub {
	my $c = shift;
	die "no file" unless $c->param("file");
	my $stack = $c->param("stack");
	mkdir "./$stack";
	$c->param("file")->move_to("./$stack/docker-compose.yml");
	$c->render(json => {ok => \1});
};

del '/:stack/file' => sub {
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
	my $ret = qx{cd ./$stack && docker-compose up -d --build --remove-orphan 2>&1};
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
