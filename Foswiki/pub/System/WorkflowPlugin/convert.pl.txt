#!/usr/bin/perl -w

while (<>) {
  $_ =~ s/APPROVALWORKFLOW/WORKFLOW/geo;
  $_ =~ s/APPROVALNOTICE/WORKFLOWNOTICE/geo;
  $_ =~ s/APPROVALBUTTON/WORKFLOWBUTTON/geo;
  $_ =~ s/APPROVALHISTORYFORMAT/WORKFLOWHISTORYFORMAT/geo;
  $_ =~ s/\%APPROVAL(.*?)\%/\%WORKFLOW$1\%/go;
  $_ =~ s/\%META:APPROVAL(.*?)\{/\%META:WORKFLOW$1\{/go;
  print $_;
  print "\n";
}
