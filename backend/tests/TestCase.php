<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Http\UploadedFile;

abstract class TestCase extends BaseTestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        // Il client di test manda "Accept-Language: en-us": come l'app italiana, chiediamo l'italiano.
        $this->withHeader('Accept-Language', 'it');
    }

    /**
     * Immagine PNG 1×1 valida (senza bisogno dell'estensione GD).
     */
    protected function photo(string $name): UploadedFile
    {
        $png = base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

        return UploadedFile::fake()->createWithContent(preg_replace('/\.\w+$/', '.png', $name), $png);
    }
}
