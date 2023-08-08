<?php

/*
 * Создание tap-файла с блоком данных
 */

function crc8($block, $crconly = false) {

    $crc = 0;
    foreach ($block as $x) $crc ^= $x;
    $block[] = $crc;
    return $crconly ? $crc : $block;
}

// Блок с кодом
// ---------------------------------------------------------------------

$code  = file_get_contents($argv[1]);
$size  = strlen($code);
$start = $argv[3];

// Первым идет блок с кодом
$block = [0x00,0x03, 0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20, ($size&255),($size>>8), ($start&255),($start>>8), 0x00,0x80];
$block = crc8($block);
$codeblock = pack("C*", 0x13,0x00, ...$block);

// Далее идет блок с данными
$block = [0xFF]; for ($i = 0; $i < $size; $i++) $block[] = ord($code[$i]); $block = crc8($block);

$size += 2;
$codeblock .= pack("C*", ($size&255),($size>>8), ...$block);

// Сохранить новый TAP файл
// ---------------------------------------------------------------------
file_put_contents($argv[2], $codeblock);

