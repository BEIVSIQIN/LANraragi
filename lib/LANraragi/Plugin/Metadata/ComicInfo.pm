package LANraragi::Plugin::Metadata::ComicInfo;

use strict;
use warnings;

use Mojo::DOM;

#You can also use the LRR Internal API when fitting.
use LANraragi::Model::Plugins;
use LANraragi::Utils::Logging qw(get_plugin_logger);
use LANraragi::Utils::Archive qw(is_file_in_archive extract_file_from_archive);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name         => "ComicInfo",
        type         => "metadata",
        namespace    => "comicinfo",
        author       => "Gin-no-kami",
        version      => "1.1",
        description  => "Parses metadata from ComicInfo.xml embedded in the archive",
        parameters => []
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    my $lrr_info = shift; # Global info hash, contains various metadata provided by LRR

    #Use the logger to output status - they'll be passed to a specialized logfile and written to STDOUT.
    my $logger = get_plugin_logger();

    my $file = $lrr_info->{file_path};
    my $path_in_archive = is_file_in_archive( $file, "ComicInfo.xml" );

    if ( $path_in_archive ) {
        #Extract ComicInfo.xml
        my $filepath = extract_file_from_archive( $file, $path_in_archive );

        #Read file into string
        my $stringxml = "";
        open( my $fh, '<:encoding(UTF-8)', $filepath )
          or return ( error => "Could not open $filepath!" );
        while ( my $line = <$fh> ) {
            chomp $line;
            $stringxml .= $line;
        }

        #Parse file into DOM object and extract tags
        my $genre = Mojo::DOM->new->xml(1)->parse($stringxml)->at('Genre')->text;
        my $url = Mojo::DOM->new->xml(1)->parse($stringxml)->at('Web')->text;
        my $group = Mojo::DOM->new->xml(1)->parse($stringxml)->at('Writer')->text;
        my $artist = Mojo::DOM->new->xml(1)->parse($stringxml)->at('Penciller')->text;
        my $lang = Mojo::DOM->new->xml(1)->parse($stringxml)->at('LanguageISO')->text;

        #Delete local file
        unlink $filepath;


        #Add prefix and concatenate
        my @found_tags;
        @found_tags = try_add_tags(\@found_tags, "group:", $group);
        @found_tags = try_add_tags(\@found_tags, "artist:", $artist);
        @found_tags = try_add_tags(\@found_tags, "source:", $url);
        push( @found_tags, "language:" . $lang ) unless !$lang;
        my @genres = split(',', $genre);
        foreach my $genre_tag (@genres){
            push(@found_tags, $genre_tag);
        }
        my $tags = join( ", ", @found_tags );

        $logger->info("Sending the following tags to LRR: $tags");
        return ( tags => $tags );
    }
    
    return ( error => "No ComicInfo.xml file found in archive");    
}

sub try_add_tags {
    my @found_tags = @{$_[0]};
    my $prefix = $_[1];
    my $tags = $_[2];
    my @tags_array = split(',', $tags);

    foreach my $tag (@tags_array) {
        push( @found_tags, $prefix . $tag );
    }
    return @found_tags;
}

1;