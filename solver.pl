use strict;
use warnings;
use Plack::Request;
use JSON;

########### Auto-Assignment #############
#
# SYNOPSIS :
#  Just run http server as below.
#
#  $ plackup solver.pl
#
# And then access : localhost:5000/
#
# SETUP :
#  Install required cpan modules.
#   Plack -- The PSGI toolkit.
#   JSON  -- JSON encoder/decoder
#
#########################################

my $json = JSON->new->allow_nonref;

my $app = sub {
  my $env = shift;
  my $req = Plack::Request->new($env);

  my $responses =
    {
     '/' => sub {
       return [
	       200,
	       [ 'Content-Type' => 'text/html'],
	       [
		'<!DOCTYPE html><html><body><form action="/solve" method="post" target="_blank">'.
		'<textarea cols="120" rows="30" name="json_content">'.
		'{'."\n".
		' "available_table" :'."\n".
		' ['."\n".
		'  {"table_id" : 201, "idle_time" : 300, "min_cap" : 2, "max_cap" : 4, "type" : "t"},'."\n".
		'  {"table_id" : 202, "idle_time" : 200, "min_cap" : 4, "max_cap" : 6, "type" : "l"},'."\n".
		'  {"table_id" : 203, "idle_time" : 500, "min_cap" : 4, "max_cap" : 6, "type" : "l"},'."\n".
		'  {"table_id" : 204, "idle_time" : 100, "min_cap" : 1, "max_cap" : 1, "type" : "c" },'."\n".
		'  {"table_id" : 205, "idle_time" : 250, "min_cap" : 1, "max_cap" : 1, "type" : "c" }'."\n".
		' ],'."\n".
		' "queue" : '."\n".
		' ['."\n".
		'  {"guest_id" : 301, "index" : 1, "use_num" : 5, "acceptable" : { "c" : 0, "t" : 1, "l" : 1 }},'."\n".
		'  {"guest_id" : 302, "index" : 2, "use_num" : 2, "acceptable" : { "c" : 0, "t" : 1, "l" : 1 }},'."\n".
		'  {"guest_id" : 303, "index" : 3, "use_num" : 1, "acceptable" : { "c" : 1, "t" : 1, "l" : 1 }},'."\n".
		'  {"guest_id" : 304, "index" : 4, "use_num" : 2, "acceptable" : { "c" : 0, "t" : 1, "l" : 1 }},'."\n".
		'  {"guest_id" : 305, "index" : 5, "use_num" : 4, "acceptable" : { "c" : 0, "t" : 1, "l" : 1 }}'."\n".
		' ]'."\n".
		'}'."\n".
		'</textarea><input type="submit" value="submit"></input></form></body></html>'
	       ]
	      ];
       },
     '/solve' => sub {
       my $json_content;
       eval {
	 $json_content = $req->parameters->{json_content};
       };
       if(my $error = $@){
	 return [
		 500,
		 [ 'Content-Type' => 'application/json' ],
		 [$json->utf8->canonical->encode({result => 'ERROR', content => $error})]
		];
       }
       my $input = $json->decode($json_content);
       my $solution;
       my $skipped_table;
       my $available_table = $input->{available_table};
       my $queue = $input->{queue};
       foreach my $table (sort {$b->{idle_time} <=> $a->{idle_time}} @$available_table){
	 my $table_id = $table->{table_id};
	 my $min_cap = $table->{min_cap};
	 my $max_cap = $table->{max_cap};
	 my $type = $table->{type};
	 my $assigned_flag = 0;
	 foreach my $guest (sort {$a->{index} <=> $b->{index}} @$queue){
	   if(defined($guest->{assigned})){
	     next;
	   }
	   my $guest_id = $guest->{guest_id};
	   my $use_num = $guest->{use_num};
	   my $acceptable = $guest->{acceptable};
	   if(($acceptable->{$type} == 1) and ($use_num >= $min_cap) and ($use_num <= $max_cap)){
	     push(@$solution,{table_id => $table_id, guest_id => $guest_id, use_num => $use_num, max_cap => $max_cap});
	     $assigned_flag = 1;
	     $guest->{assigned} = 1;
	     last;
	   }
	 }
	 if($assigned_flag == 0){
	   push(@$skipped_table,$table_id);
	 }
       }
       my $skipped_guest;
       foreach my $guest ( @$queue ){
	 unless(defined($guest->{assigned})){
	   push(@$skipped_guest,$guest->{guest_id});
	 }
       }
       my $output =
	 {
	  result => 'OK',
	  content =>
	  {
	   solution => $solution,
	   skipped_table => $skipped_table,
	   skipped_guest => $skipped_guest
	  }
	 };
       return [
	       200,
	       ['Content-Type', => 'application/json'],
	       [$json->utf8->canonical->encode($output)]
	       ];
     }
    };
  if(defined($responses->{$env->{PATH_INFO}})){
    return $responses->{$env->{PATH_INFO}}->();
  }else{
    return [
	    404,
	    [ 'Content-Type' => 'text/plain' ],
	    [ '404 Not found.' ]
	   ];
  }
};

return $app;
