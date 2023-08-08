<?php

// Заполнение таблицы attr
for ($i = 0; $i < 256; $i++) {
    
    $lo = ($i & 7);
    $hi = ($i >> 3) & 7;
    $br = ($i & 0x40) >> 3;
    
    if ($i & 0x80) {
        $data = ($lo | $br)*256 + ($hi | $br);
    } else {
        $data = ($hi | $br)*256 + ($lo | $br);
    }
    
    if (($i & 7) == 0) echo "    dw ";
    echo sprintf("$%04x" . (($i & 7) == 7 ? "\n" : ", "), $data);
}

