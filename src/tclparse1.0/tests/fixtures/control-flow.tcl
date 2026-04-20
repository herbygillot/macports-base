if {$x == 1} {
    puts one
} elseif {$x == 2} {
    puts two
} else {
    puts other
}

foreach item {a b c} {
    puts $item
}

while {$i < 10} {
    incr i
}

for {set i 0} {$i < 10} {incr i} {
    puts $i
}

switch $mode a {
    puts "mode a"
} b {
    puts "mode b"
} default {
    puts "unknown"
}

switch $mode {
    a { puts "list-form a" }
    b { puts "list-form b" }
    default { puts "list-form default" }
}
