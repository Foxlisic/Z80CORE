<?php

$base = $argv[2] ?? 128;
$outf = $argv[3] ?? "";

$im = imagecreatefrompng($argv[1]);
$sx = imagesx($im);
$sy = imagesy($im);

$uni = [];

for ($y = 0; $y < $sy; $y += 16)
for ($x = 0; $x < $sx; $x += 8) {

    $out = [];
    for ($i = 0; $i < 16; $i++) {

        $m = 0;
        for ($j = 0; $j < 8; $j++) {

            $m <<= 1;
            if (imagecolorat($im, $x + $j, $y + $i)) {
                $m |= 1;
            }
        }

        $out[] = sprintf("$%02x", $m);
    }

    $str = "defb ".join(',', $out);
    $res[] = $str;
    $uni[$str] = 1;
}

$uni = array_flip(array_keys($uni));


$html  = "chrs:\n";
$html .= join("\n", array_keys($uni))."\n";
$html .= "tilemap:\n";

for ($y = 0; $y < $sy; $y += 16) {

    $html .= "    defb ";
    $out = [];
    for ($x = 0; $x < $sx; $x += 8) {

        $i = ($x / 8) + ($y / 16)*($sx / 8);
        $str = $res[$i];
        $out[] = sprintf("$%02x", $uni[$str] + $base);
    }
    $html .= join(',', $out)."\n";
}

if ($outf) file_put_contents($outf, $html); else echo $html;
