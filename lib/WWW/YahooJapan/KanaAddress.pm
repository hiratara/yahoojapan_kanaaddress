package WWW::YahooJapan::KanaAddress;

require 5.006;

use warnings;
use strict;
use Carp;

use version; our $VERSION = qv('0.1.2');

use LWP::UserAgent;
use URI::Escape;

my %_tdfk_dict = qw/
�̳�ƻ �ۤä����ɤ�
�Ŀ��� ������ꤱ��
��긩 ����Ƥ���
�ܾ븩 �ߤ䤮����
���ĸ� ����������
������ ��ޤ�������
ʡ�縩 �դ����ޤ���
��븩 ���Ф餭����
���ڸ� �Ȥ�������
���ϸ� ����ޤ���
��̸� �������ޤ���
���ո� ���Ф���
����� �Ȥ����礦��
����� ���ʤ��櫓��
�ٻ��� �Ȥ�ޤ���
���㸩 �ˤ���������
��� �������櫓��
ʡ�温 �դ�������
������ ��ޤʤ�����
Ĺ� �ʤ��Τ���
���츩 ���դ���
�Ų��� ������������
���θ� ����������
���Ÿ� �ߤ�����
���츩 ��������
������ ���礦�Ȥ�
����� ����������
ʼ�˸� �Ҥ礦������
���ɸ� �ʤ餱��
�²λ��� �狼��ޤ���
Ļ�踩 �ȤäȤꤱ��
�纬�� ���ޤͤ���
������ ������ޤ���
���縩 �Ҥ��ޤ���
������ ��ޤ�������
���縩 �Ȥ����ޤ���
��� �����櫓��
��ɲ�� ���Ҥᤱ��
���θ� ����������
ʡ���� �դ���������
���츩 ��������
Ĺ�긩 �ʤ���������
���ܸ� ���ޤ�Ȥ���
��ʬ�� ������������
�ܺ긩 �ߤ䤶������
�����縩 �������ޤ���
���츩 �����ʤ櫓��
/;

my $search_url_tpl = 'http://search.map.yahoo.co.jp/search?p=%s&ei=euc-jp';
my $kana_url_tpl   = 'http://map.yahoo.co.jp/address?ac=%s';


# a constructor
sub new{ 
    my $class = shift;

    my %opt = ref($_[0]) ? %{$_[0]} : @_;

    my $ua = $opt{ua} || LWP::UserAgent->new();

    bless {ua => $ua}, $class;
};


# strip tags from HTML
sub _strip_tag{
    my $self = shift;
    my @strs = @_;
    return map { my $s = $_; $s =~ s/<[^>]+>//g; $s; } @strs;
}


# search from Yahoo Maps by free word.
# the return value is raw html.
sub _do_freeword_search{
    my $self = shift;
    my $word = shift;

    my $url = sprintf($search_url_tpl, uri_escape($word));

    my $ua  = $self->{ua};
    my $res = $ua->get($url);
    return $res->content();
}


# change CHO-AZA into CHO-AZA of Yahoo expression.
# params: TO-DO-FU-KEN, SHI-KU(Yahoo exp.), CHO-AZA
# return: CHO-AZA(Yahoo exp.)
sub _correct_choaza{
    my $self = shift;
    my ($tdfk, $corrected_shiku, $choaza) = @_;

    my $html = $self->_do_freeword_search($tdfk . $corrected_shiku . $choaza);

    # use first element of the search result.
    my $corrected_address = undef;
    if ($html =~ 
        m{<a [^>]+http://map\.yahoo\.co\.jp/pl\?p=[^>]+>(.+?)</a>}) {
        $corrected_address = $1;
    }else{
        die "can't find $corrected_shiku, $choaza .";
    }

    # chop SHI-KU
    my $regex = quotemeta($tdfk. $corrected_shiku);
    $corrected_address =~ s/^$regex//;

    # chop address-number
    $corrected_address =~ s/[0-9]+$//;

    # chop chome
    $corrected_address =~ s/[0-9]+����$//;

    return $corrected_address;
}


# change SHI-KU into SHI-KU of Yahoo expression.
# params: TO-DO-FU-KEN, SHI-KU
# return: SHI-KU ID, SHI-KU(Yahoo exp.)
sub _correct_shiku{
    my $self = shift;
    my ($tdfk, $shiku) = @_;

    my $html = $self->_do_freeword_search($tdfk . $shiku);

    my @codes = ();
    while ($html =~ 
           m{<a [^>]+map\.yahoo\.co\.jp/address\?ac=(\d+)[^>]+>(.+?)</a>}g) {
        push(@codes, [$1, $2]);
    }
    die "can't determine codes: " . join(',', @codes) if(@codes != 1);

    my ($code, $corrected_shiku) = @{ $codes[0] };

    # chop TO-DO-HU-KEN part
    my $regexp = quotemeta($tdfk);
    $corrected_shiku =~ s/^$regexp//;

    return ($code, $corrected_shiku);
}


# get address(kanji) and kana mapping in given SHI-KU (or TO-DO-HU-KEN)
# params: SHI-KU ID (or TO-DO-HU-KEN ID)
# return: kanji-kana mapping hash reference: {kanji1 => kana1, kanji2 => kana2}
sub _get_kana_dict{
    my $self = shift;
    my $shiku_code = shift;
    my $url = sprintf($kana_url_tpl, $shiku_code);

    my $ua  = $self->{ua};
    my $res = $ua->get($url);
    my $c = $res->content();
    my %ret = ();
    while ($c =~ m{<dd><div class="ruby">(.+?)</div>(.+?)</dd>}g) {
        my ($kana, $kanji) = $self->_strip_tag($1, $2);
        $ret{$kanji} = $kana;
    }
    return \%ret;
}


# get kana of the address
# params: TO-DO-HU-KEN, SHI-KU, CHO-AZA
# return: TO-DO-HU-KEN(kana), SHI-KU(kana), CHO-AZA(kana)
sub search{
    my $self = shift;
    my ($tdfk, $shiku, $choaza) = @_;

    # We need ID of SHIKU and TODOHUKEN to get kana.
    # We can also get SHIKU(Yahoo Exp.) incidentally.
    my ($shiku_code, $corrected_shiku) = $self->_correct_shiku($tdfk, $shiku);
    my $tdfk_code = substr($shiku_code, 0, 2);

    my $ref_choaza = $self->_get_kana_dict($shiku_code);
    my $ref_shiku  = $self->_get_kana_dict($tdfk_code);

    # SHI-KU
    my $shiku_kana = $ref_shiku->{$corrected_shiku};

    # CHO-AZA
    my $corrected_choaza = '';
    my $choaza_kana = '';
    if(exists $ref_choaza->{$choaza}){
        # the kana was found fortunately.
        $choaza_kana = $ref_choaza->{$choaza};
    }else{
        # retry by using Yahoo Expression
        $corrected_choaza = $self->_correct_choaza(
            $tdfk, $corrected_shiku, $choaza);
        $choaza_kana = $ref_choaza->{$corrected_choaza} 
        if exists $ref_choaza->{$corrected_choaza};
    }

    die sprintf("can't read: input(%s, %s), search(%s, %s)", 
                $shiku, $choaza, $corrected_shiku, $corrected_choaza)
        if ! $shiku_kana or ! $choaza_kana;

    return $_tdfk_dict{$tdfk}, $shiku_kana,$choaza_kana;
}




1; # Magic true value required at end of module
__END__

=encoding euc-jp

=head1 NAME

WWW::YahooJapan::KanaAddress - translating the address in Japan into kana.

=head1 SYNOPSIS

    use WWW::YahooJapan::KanaAddress;

    my $yahoo = WWW::YahooJapan::KanaAddress->new();
    print $yahoo->search('������', '����Į', 'Ļ��'), "\n";

results:

    ��ޤʤ����󤫤���������礦�Ȥ�

=head1 DESCRIPTION

This class translates the address written in Kanji into Kana by using Yahoo! Japan Maps.

=head2 Methods

=over

=item my $yahoo = WWW::YahooJapan::KanaAddress->new( ua => 'your LWP::UserAgent');

a constructor. You can set a LWP::UserAgent object if you want.

=item my ($kana_ken, $kana_shiku, $kana_choaza) = $yahoo->search($ken, $shiku, $choaza);

search kana by Yahoo!Japan Maps. The arguments and return values must be encoded to euc-jp. You can't use unicode string.

=over 2

=item $ken

Prefecture in Japan, should be ended with '��' or 'ƻ' or '��' or '��'.

=item $shiku

Name of city and district, should be ended with '��' or '��' or 'Į' or '¼'.

=item $choaza

The rest of the string of address. It might contain 'Į' and '��'.

=back

You can use a vague address to some degree. For example: 

    print $yahoo->search('��븩', 'ζ�����', '��Į'), "\n";
    print $yahoo->search('��븩', 'ζ���', '��Į'), "\n";
    print $yahoo->search('��븩', 'ε�����', '��Į'), "\n";

These sentences output the same result. This is a function of Yahoo!Japan Maps.

=back

=head1 CONFIGURATION AND ENVIRONMENT

WWW::YahooJapan::KanaAddress requires no configuration files or environment variables.


=head1 DEPENDENCIES

LWP::UserAgent, and Yahoo!Japan :-p


=head1 INCOMPATIBILITIES

None reported.


=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<hiratara@cpan.org>, or through the web interface at L<http://rt.cpan.org>.


=head1 AUTHOR

Masahiro Honma  C<< <hiratara@cpan.org> >>
