#!/usr/bin/perl -w

# To use this script on one topic, run:
# perl convert.pl TopicName.txt
# If you have several topics to change, copy
# this into the web direcory (i.e. data/Main/)
# and use the following bash commands:
# 1. for i in `ls *.txt*`; do perl convert.pl < $i > $i.mod; done
# 2. for i in *.mod; do mv $i `basename $i .mod`; done
# _Thanks to EdMcDonagh for the bash commands_
#
# Note: Always test on a COPY of your data first!

while (<>) {
    $_ =~ s/WORKFLOWHISTORYFORMAT/APPROVALHISTORYFORMAT/geo;
    $_ =~ s/WORKFLOWSTATEMESSAGE/APPROVAL{"statemessage"}/go;
    $_ =~ s/WORKFLOWTRANSITION/APPROVAL{"transition"}/go;
    $_ =~ s/REVIEWEDBY/APPROVAL{"reviewedby"}/go;
    $_ =~
s/\%META:WORKFLOWHISTORY{(.*?)}%/\%META:APPROVALHISTORY{name="APPROVALHISTORY" $1 }%/go;
    $_ =~ s/WORKFLOWHISTORY/APPROVAL{"history"}/go;
    $_ =~ s/\%META:WORKFLOW(.*?)\{/\%META:APPROVAL$1\{/go;
    $_ =~ s/Set WORKFLOW/Set APPROVALDEFINITION/go;
    print $_;
}
