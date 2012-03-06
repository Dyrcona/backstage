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
package Backstage::Import;

use strict;
use warnings;

use Carp;
use MARC::Record;
use MARC::File::XML;
use MARC::File::USMARC;
use OpenILS::Utils::Cronscript;
use OpenILS::Utils::Normalize qw(clean_marc);
use DateTime;
use DateTime::Format::ISO8601;
use Encode;

my $U = 'OpenILS::Application::AppUtils';

sub new {
    my $class = shift;
    my $self = {};
    $self->{'prefs'} = shift;
    $self->{'utf8'} = 0;
    my $dstr = $self->{'prefs'}->export->last_run_date;
    $dstr =~ s/ /T/;
    $dstr =~ s/\.\d+//;
    $self->{'export_date'} = DateTime::Format::ISO8601->parse_datetime($dstr);
    bless($self, $class);
    return $self;
}

sub doFile {
    my $self = shift;
    my $filename = shift;
    my $isUTF8 = (($filename =~ /\.UTF8$/) || $self->{'utf8'});
    my $file = MARC::File::USMARC->in($filename, ($isUTF8) ? 'UTF8' : undef);
    if ($file) {
        $self->{'scr'} = OpenILS::Utils::Cronscript->new({nolockfile=>1});
        $self->{'auth'} = $self->{'scr'}->authenticate(
            $self->{'prefs'}->evergreen->authentication->TO_JSON
        );
        if ($filename =~ /\.BIB\./) {
            $self->doBibs($file);
        } else {
            carp "We don't do authorities, yet."
        }
        $file->close();
        $self->{'scr'}->logout;
    } else {
        carp "Failed to read MARC from $filename.";
    }
}

sub doBibs {
    my $self = shift;
    my $file = shift;
    my $editor = $self->{'scr'}->editor(authtoken=>$self->{'auth'});
    while (my $input = $file->next()) {
        my $id = $input->subfield('901', 'c');
        if ($id) {
            my $bre = $editor->retrieve_biblio_record_entry($id);
            next if ($U->is_true($bre->deleted));
            my $record = MARC::Record->new_from_xml($bre->marc, 'UTF8');
            my $str = $bre->edit_date;
            $str =~ s/\d\d$//;
            my $edit_date = DateTime::Format::ISO8601->parse_datetime($str);
            if (DateTime->compare($edit_date, $self->{'export_date'}) < 0) {
                my $needImport = 1;
                my $bslw_date = undef;
                my $rec_date = undef;
                $bslw_date = DateTime::Format::ISO8601->parse_datetime(
                    fix005($input->field('005')->data())
                ) if (defined($input->field('005')));
                $rec_date = DateTime::Format::ISO8601->parse_datetime(
                    fix005($record->field('005')->data())
                ) if (defined($record->field('005')));
                if (defined($rec_date)) {
                    $needImport = DateTime->compare($bslw_date, $rec_date);
                }
                if ($needImport > 0) {
                    print("Import $id\n");
                    my $newMARC = $input->as_xml_record();
                    $bre->marc(clean_marc($newMARC));
                    $bre->edit_date('now()');
                    $editor->xact_begin;
                    $editor->update_biblio_record_entry($bre);
                    $editor->commit;
                } else {
                    print("Keep $id\n");
                }
            }
        } else {
            carp "No 901\$c in input record $id";
        }
    }
    $editor->finish;
}

sub utf8 {
    my $self = shift;
    if (@_) {
        $self->{'utf8'} = shift;
    }
    return $self->{'utf8'};
}

sub fix005 {
    my $in = shift;
    substr($in,8,0) = 'T';
    $in =~ s/\.0$//;
    return $in;
}

1;
