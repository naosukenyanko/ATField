#!/usr/bin/perl
#2013/11/08 なおすけ
use strict;
use NET::Twitter;
use utf8;
use Data::Dumper;
use Time::Piece;
binmode STDOUT, ":utf8";
my $handle;

sub main {
	#設定のロード
	open my $fh, "<", "setting.txt" or die "cannot read setting.txt";
	my $consumer_key = <$fh>;
	my $consumer_secret = <$fh>;
	my $access_token = <$fh>;
	my $access_token_secret = <$fh>;
	close $fh;

	chomp($consumer_key);
	chomp($consumer_secret);
	chomp($access_token);
	chomp($access_token_secret);

	#接続
	$handle = Net::Twitter->new({ traits => [qw/OAuth API::RESTv1_1/],
								  consumer_key => $consumer_key,
								  consumer_secret => $consumer_secret,
								  access_token => $access_token,
								  access_token_secret => $access_token_secret});


	my $tname = shift @ARGV;
	if(!defined($tname) || $tname eq ''){
		print "target name: ";
		chomp($tname = <STDIN>);
	}
	my $list;
	eval{
		$list = get_follow_list($tname);
	};
	if($@){
		$list = get_reply_list($tname);
	}
	my $n = @{$list};
	if($n == 0) {
		exit;
	}
	while(1){
		print "You will block $n account, really? (yes/no)\n";
		my $ans = <STDIN>;
		chomp($ans);
		if($ans eq 'yes'){
			last;
		}
		if($ans eq 'no'){
			exit;
		}
	}
	$list = block_all($list);
	write_log($list);

	print "done.\n";
}

sub get_reply_list {
	my $tname = shift;
	#print "$tname\n";
	my @list = ();

	my $rs = $handle->search({q=>$tname, lang=>"ja", count=>100, result_type=>'recent'});
	if( (ref $rs) eq 'HASH' || exists $rs->{statueses}){
		foreach my $tw (@{$rs->{statuses}}){
			if($tw->{in_reply_to_screen_name} eq $tname){
				push @list, $tw->{user};
			}
		}
	}

	return \@list;
}

sub get_follow_list {
	my $tname = shift;
	my @list = ();
	my $cur = -1;
	while($cur != 0){
		my $rs = $handle->followers_list({screen_name=>$tname, count=>200, cursor=>$cur});
		if( (ref $rs) eq 'HASH' || exists $rs->{users}){
			push @list, @{$rs->{users}};
			$cur = $rs->{next_cursor};
		}else{
			last;
		}
	}
	return \@list;
}

sub block_all {
	my $list = shift;
	my @ret = ();
	foreach my $us(@{$list}){
		my $rs = $handle->create_block({user_id => $us->{id}});
		if($rs){
			push @ret, $rs;
		}
	}
	return \@ret;
}

sub write_log {
	my $list = shift;
	my $num = @{$list};
	# Time::Pieceオブジェクトの取得
	my $t = localtime;

	# 日付や時刻の情報の取得
	my $year   = $t->year;
	my $month  = $t->mon;
	my $mday   = $t->mday;

	my $hour   = $t->hour;
	my $minute = $t->minute;
	my $second = $t->sec;
	my $timestamp = sprintf("%04d/%02d/%02d %02d:%02d:%02d", 
							$year, $month, $mday, $hour, $minute, $second);
	open my $fh, ">>", "log.txt" or die "cannot open log.txt";
	print $fh "\n[ $timestamp ]\n";
	print $fh "block $num account.\n";
	print $fh join("\n", map{$_->{screen_name} }@{$list}) . "\n";

	close $fh;
}

main();
