use strict;
use warnings;

use Test::More 0.88;
use Test::Fatal;
use Test::Warnings qw( warning warnings );

{
    ## no critic (BuiltinFunctions::ProhibitStringyEval, ErrorHandling::RequireCheckingReturnValueOfEval)
    like(
        exception {
            eval 'package Whatever; use Package::DeprecationManager;';
            die $@ if $@;
        },
        qr/^\QYou must provide a hash reference -deprecations parameter when importing Package::DeprecationManager/,
        'must provide a set of deprecations when using Package::DeprecationManager'
    );
}

## no critic (Modules::ProhibitMultiplePackages)

{
    package Foo;

    use Package::DeprecationManager -deprecations => {
        'Foo::foo'  => '0.02',
        'Foo::bar'  => '0.03',
        'Foo::baz'  => '1.21',
        'not a sub' => '1.23',
    };

    sub foo {
        deprecated('foo is deprecated');
    }

    sub bar {
        deprecated('bar is deprecated');
    }

    sub baz {
        deprecated();
    }

    sub quux {
        if ( $_[0] > 5 ) {
            deprecated(
                message => 'quux > 5 has been deprecated',
                feature => 'not a sub',
            );
        }
    }

    sub varies {
        deprecated("The varies sub varies: $_[0]");
    }

}

{
    package Bar;

    Foo->import();

    ::like(
        ::warning { Foo::foo() },
        qr/\Qfoo is deprecated/,
        'deprecation warning for foo'
    );

    ::like(
        ::warning { Foo::bar() },
        qr/\Qbar is deprecated/,
        'deprecation warning for bar'
    );

    ::like(
        ::warning { Foo::baz() },
        qr/\QFoo::baz has been deprecated since version 1.21/,
        'deprecation warning for baz, and message is generated by Package::DeprecationManager'
    );

    ::is_deeply(
        [ ::warnings { Foo::foo() } ],
        [],
        'no warning on second call to foo'
    );

    ::is_deeply(
        [ ::warnings { Foo::bar() } ],
        [],
        'no warning on second call to bar'
    );

    ::is_deeply(
        [ ::warnings { Foo::baz() } ],
        [],
        'no warning on second call to baz'
    );

    ::like(
        ::warning { Foo::varies(1) },
        qr/\QThe varies sub varies: 1/,
        'warning for varies sub'
    );

    ::like(
        ::warning { Foo::varies(2) },
        qr/\QThe varies sub varies: 2/,
        'warning for varies sub with different error'
    );

    ::is_deeply(
        [ ::warnings { Foo::varies(1) } ],
        [],
        'no warning for varies sub with same message as first call'
    );
}

{
    package Baz;

    Foo->import( -api_version => '0.01' );

    ::is_deeply(
        [ ::warnings { Foo::foo() } ],
        [],
        'no warning for foo with api_version = 0.01'
    );

    ::is_deeply(
        [ ::warnings { Foo::bar() } ],
        [],
        'no warning for bar with api_version = 0.01'
    );

    ::is_deeply(
        [ ::warnings { Foo::baz() } ],
        [],
        'no warning for baz with api_version = 0.01'
    );
}

{
    package Quux;

    Foo->import( -api_version => '1.17' );

    ::like(
        ::warning { Foo::foo() },
        qr/\Qfoo is deprecated/,
        'deprecation warning for foo with api_version = 1.17'
    );

    ::like(
        ::warning { Foo::bar() },
        qr/\Qbar is deprecated/,
        'deprecation warning for bar with api_version = 1.17'
    );

    ::is_deeply(
        [ ::warnings { Foo::baz() } ],
        [],
        'no warning for baz with api_version = 1.17'
    );
}

{
    package Another;

    Foo->import();

    ::is_deeply(
        [ ::warnings { Foo::quux(1) } ],
        [],
        'no warning for quux(1)'
    );

    ::like(
        ::warning { Foo::quux(10) },
        qr/\Qquux > 5 has been deprecated/,
        'got a warning for quux(10)'
    );
}

{
    package Dep;

    use Package::DeprecationManager -deprecations => {
        'Dep::foo' => '1.00',
        },
        -ignore => [ 'My::Package1', 'My::Package2' ];

    sub foo {
        deprecated('foo is deprecated');
    }
}

{
    package Dep2;

    use Package::DeprecationManager -deprecations => {
        'Dep2::bar' => '1.00',
        },
        -ignore => [qr/My::Package[12]/];

    sub bar {
        deprecated('bar is deprecated');
    }
}

{
    package My::Package1;

    sub foo { Dep::foo() }
    sub bar { Dep2::bar() }
}

{
    package My::Package2;

    sub foo { My::Package1::foo() }
    sub bar { My::Package1::bar() }
}

{
    package My::Baz;

    ::like(
        ::warning { My::Package2::foo() },
        qr/^foo is deprecated at t.basic\.t line \d+\.?\s+My::Baz/,
        'deprecation warning for call to My::Package2::foo() and mentions My::Baz but not My::Package[12]'
    );

    ::is_deeply(
        [ ::warnings { My::Package2::foo() } ],
        [],
        'no deprecation warning for second call to My::Package2::foo()'
    );

    ::is_deeply(
        [ ::warnings { My::Package1::foo() } ],
        [],
        'no deprecation warning for call to My::Package1::foo()'
    );

    ::like(
        ::warning { My::Package2::bar() },
        qr/^bar is deprecated at t.basic\.t line \d+\.?\s+My::Baz/,
        'deprecation warning for call to My::Package2::foo() and mentions My::Baz but not My::Package[12]'
    );

    ::is_deeply(
        [ ::warnings { My::Package2::bar() } ],
        [],
        'no deprecation warning for second call to My::Package2::bar()'
    );
}

{
    package My::Quux;

    ::like(
        ::warning { My::Package1::foo() },
        qr/^foo is deprecated at t.basic\.t line \d+\.?\s+My::Quux/,
        'deprecation warning for call to My::Package1::foo() and mentions My::Quux but not My::Package[12]'
    );

    ::is_deeply(
        [ ::warnings { My::Package1::foo() } ],
        [],
        'no deprecation warning for second call to My::Package1::foo()'
    );
}

done_testing();