#!/usr/bin/env perl
use Mojolicious::Lite;
use Mojo::JSON qw/from_json/;
use Mojo::UserAgent;
use MongoDB;
use YAML;

helper ua => sub {
	state $ua ||= Mojo::UserAgent->new;
};

helper mongo => sub {
	state $mongo ||= MongoDB->connect('mongodb://mongo')
};

helper db => sub {
	my $c		= shift;
	state $db	||= $c->app->mongo->get_database("watcher");
};

helper separe_file => sub {
	my $c		= shift;
	my $file	= Load(shift);

	my %scale;
	$c->app->log->debug($c->app->dumper($file));
	if(exists $file->{services}) {
		for my $service(keys %{ $file->{services} }) {
			next unless exists $file->{services}{$service}{scaling};
			$scale{$service} = delete $file->{services}{$service}{scaling};
			$scale{$service}{min} = 0 unless exists $scale{$service}{min};
			$scale{$service}{initial} = $scale{$service}{min}
				if exists $scale{$service}{min}
					and (
						not exists $scale{$service}{initial}
						or $scale{$service}{initial} < $scale{$service}{min}
					)
			;
		}
	}

	{compose => $file, scale => \%scale}
};

post "/:stack" => sub {
	my $c	= shift;
	die "no file" unless $c->param("file");
	my $stack = $c->param("stack");
	my $filename = "/tmp/$stack-$$-" . time . "-" . rand(10000) . ".yml";
	my $file = $c->param("file")->slurp;
	my $data = $c->separe_file($file);
	$c->app->log->debug($c->app->dumper($data));
	my $col = $c->db->get_collection("stacks");
	eval {$col->insert_one({ _id	=> $stack, %$data }) };
	$col->update_one( {"_id" => $stack}, {'$set' => $data}) if $@;

	$c->render(json => {ok => \1});
};

app->start;
