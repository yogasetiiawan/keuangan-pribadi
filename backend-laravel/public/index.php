<?php

define('LARAVEL_START', microtime(true));

// Jika dependencies Composer sudah di-install, jalankan Laravel penuh.
// Jika belum (`vendor/autoload.php` belum ada), jalankan Standalone API Runner
// yang menggunakan database SQLite & GoogleSheetService yang sama.
if (file_exists(__DIR__ . '/../vendor/autoload.php') && file_exists(__DIR__ . '/../bootstrap/app.php')) {
    require __DIR__ . '/../vendor/autoload.php';
    $app = require_once __DIR__ . '/../bootstrap/app.php';
    $kernel = $app->make(Illuminate\Contracts\Http\Kernel::class);
    $response = $kernel->handle(
        $request = Illuminate\Http\Request::capture()
    )->send();
    $kernel->terminate($request, $response);
} else {
    require __DIR__ . '/../bootstrap/standalone_api.php';
}
