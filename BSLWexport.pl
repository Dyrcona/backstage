#!/usr/bin/perl
# ---------------------------------------------------------------
# Copyright © 2012 Merrimack Valley Library Consortium
# Jason Stephenson <jstephenson@mvlc.org>

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# ---------------------------------------------------------------

use strict;
use warnings;

use JSONPrefs;
use Backstage::Export;
use Backstage::Email;
use Backstage::FTP;

my ($prefs_file, $upload_file);

my $dry_run = 0;

while (@ARGV) {
    my $arg = shift @ARGV;
    if ($arg eq '-c') {
        $prefs_file = shift @ARGV;
    } elsif ($arg eq '-f') {
        $upload_file = shift @ARGV;
    } elsif ($arg eq '-n') {
        $dry_run = 1;
    } else {
        die("Invalid argument $arg");
    }
}

if ($dry_run && $upload_file) {
    die("Dry run (-n) is not compatible with upload file (-f)");
}

$prefs_file ||= $ENV{'HOME'} . "/myprefs.d/bslw.json";

my $prefs = JSONPrefs->load($prefs_file);

unless ($upload_file) {
    my $exporter = Backstage::Export->new($prefs);
    $upload_file = $exporter->run($dry_run);
}

if ($upload_file && !$dry_run) {
    my $ftp = Backstage::FTP->new($prefs);
    my $remote_file = $ftp->upload($upload_file);
    if ($remote_file) {
        my $email = Backstage::Email->new($prefs);
        $email->add_recipient(@{$prefs->export->recipients});
        $email->subject('BSLW Export Success');
        $email->add_part(
            {
                Data => $remote_file . " uploaded to FTP server",
                Type => 'TEXT'
            }
        );
        $email->send;
    } else {
        die("Failed to upload " . $upload_file);
    }
} elsif (!$dry_run) {
    die("Failed to export " . $prefs->export->output);
}

