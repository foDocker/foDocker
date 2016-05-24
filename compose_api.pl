#!/usr/bin/env perl
use Mojolicious::Lite;
use File::Path qw/rmtree/;
use Git::Class;
use Mojo::JSON qw/from_json/;
use YAML;

helper instances => sub {
	state $instances //= {};
};

helper git => sub {
	state $git //= Git::Class::Cmd->new;
};

helper get_scales => sub {
	my $c		= shift;
	my $stack	= shift;
	my %services;
	open my $IDS, "cd $stack && docker-compose ps -q |" || die $!;
	my $ids = join " ", map {chomp; $_} <$IDS>;
	return %services unless $ids;
	$c->app->log->debug("IDS: $ids");
	open my $INSPECT, qq{docker inspect $ids|} || die $!;
	for my $data(@{ from_json(join "", <$INSPECT>) }) {
		next unless $data->{State}{Running};
		$services{$1}++ if $data->{Name} =~ /^\/\w+?_(\w+?)_\d+$/
	}
	%services
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

post '/:stack' => sub {
	my $c = shift;
	#die "no data" unless $c->res->json;
	my $stack = $c->param("stack");
	mkdir "./$stack";
	open my $FILE, ">", "./$stack/docker-compose.yml";
	print {$FILE} Dump($c->res->json);
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
	system "cd ./$stack && docker-compose ps" || die $!;
	$c->render(json => {$c->get_scales($stack)});
};

post '/:stack/run' => sub {
	my $c		= shift;
	my $stack	= $c->param("stack");
	my $body	= $c->req->json;
	system "cd ./$stack && docker-compose up -d --build --remove-orphan 2>&1" || die $!;
	if(defined $body) {
                my %tmp;
                my @keys	= keys %$body;
		my %scale	= $c->get_scales($stack);
                my $scales	= join " ", map {
			my $instances	= $body->{$_};
			if($instances =~  /^\+(\d+)$/) {
				$instances = $scale{$_} + $1;
			} elsif($instances =~  /^-(\d+)$/) {
				$instances = $scale{$_} - $1;
			} elsif($instances =~  /^\*(\d+)$/) {
				$instances = $scale{$_} * $1;
			} elsif($instances =~  /^\/(\d+)$/) {
				$instances = $scale{$_} / $1;
			}
			$instances = 0 if $instances < 0;
			"$_=$instances"
                } keys %$body;
		system "cd ./$stack && docker-compose scale $scales 2>&1" || die $!;
	}
	$c->render(json => {$c->get_scales($stack)});
};

del '/:stack/run' => sub {
	my $c = shift;
	my $stack = $c->param("stack");
	system "cd ./$stack && docker-compose down --force 2>&1" || die $!;
	$c->render(json => {$c->get_scales($stack)});
};

app->start;
