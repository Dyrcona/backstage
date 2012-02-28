#!/usr/bin/perl
# ---------------------------------------------------------------
# Copyright © 2012 Merrimack Valley Library Consortium
# Jason Stephenson <jstephenson@mvlc.org>

# This program is free software; you can redistribute it and/or modify
# it under the terms of the Lesser GNU General Public License as
# published by the Free Software Foundation; either version 3 of the
# License, or (at your option) any later version.

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

my $prefs_file = $ARGV[0] || $ENV{'HOME'} . "/myprefs.d/bslw.json";

my $prefs = JSONPrefs->load($prefs_file);

my $exporter = Backstage::Export->new($prefs);

my $upload_file = $exporter->run;

my $email = Backstage::Email->new($prefs);
$email->add_recipient(@{$prefs->export->recipients});

if ($upload_file) {
    $email->subject('BSLW Export Success');
    $email->add_part(
        {
            Data => "File is ready for upload to Backstage in "
                . $upload_file,
            Type => 'TEXT'
        }
    );
} else {
    $email->subject('BSLW Export Failure');
    $email->add_part(
        {
            Data => "Failed to export file to " . $prefs->export->output,
            Type => 'TEXT'
        }
    );
}

$email->send;
