
use Test;

BEGIN { plan tests => 7 };

use Pretty::Table; ok(1);

my $pt = Pretty::Table->new(
    'data_type'      => 'row',
    'data_format'    => 'ucfirst',
    'if_has_title'   => 1,
    'title'          => 'Pretty::Table Test',
    'if_multi_lines' => 1,
    'max_col_length' => 5,
); ok(2);

my $dr = [
    ['id', 'name', 'sex', 'age'],
    ['01', 'zhangsan', 'male', '20'],
    ['02', 'lisi', 'male', '21'],
    ['03', 'shanleiguang', 'male', '27'],
];

$pt->get_data_format(); ok(3);
$pt->set_data_format('normal'); ok(4);
$pt->set_data_ref($dr); ok(5);
$pt->set_title('Testing'); ok(6);
$pt->output(); ok(7);
