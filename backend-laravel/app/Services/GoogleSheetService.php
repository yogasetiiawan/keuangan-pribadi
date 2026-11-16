<?php

namespace App\Services;

class GoogleSheetService
{
    protected string $webhookUrl;
    protected string $spreadsheetId;
    protected string $tabName;
    protected string $serviceAccountPath;

    public function __construct(array $config = [])
    {
        $this->webhookUrl = $config['webhook_url'] ?? $this->envVal('GOOGLE_SHEETS_WEBHOOK_URL', '');
        $this->spreadsheetId = $config['spreadsheet_id'] ?? $this->envVal('GOOGLE_SHEETS_SPREADSHEET_ID', '');
        $this->tabName = $config['tab_name'] ?? $this->envVal('GOOGLE_SHEETS_TAB_NAME', 'Transaksi');
        $this->serviceAccountPath = $config['service_account_path'] ?? $this->envVal('GOOGLE_SERVICE_ACCOUNT_JSON_PATH', 'storage/app/google-service-account.json');
    }

    protected function envVal(string $key, string $default = ''): string
    {
        if (function_exists('env')) {
            return (string) (env($key, $default) ?? $default);
        }
        return (string) ($_ENV[$key] ?? getenv($key) ?: $default);
    }

    public function isConfigured(): bool
    {
        if (!empty($this->webhookUrl)) {
            return true;
        }
        if (!empty($this->spreadsheetId) && file_exists($this->resolvePath($this->serviceAccountPath))) {
            return true;
        }
        return false;
    }

    public function getMode(): string
    {
        if (!empty($this->webhookUrl)) {
            return 'apps_script_webhook';
        }
        if (!empty($this->spreadsheetId) && file_exists($this->resolvePath($this->serviceAccountPath))) {
            return 'service_account_api';
        }
        return 'not_configured';
    }

    /**
     * Sinkronisasi 1 transaksi (Insert / Update) ke Google Sheets
     */
    public function upsertTransaction(array $transaction): array
    {
        if (!empty($this->webhookUrl)) {
            return $this->sendWebhook([
                'action' => 'upsert',
                'transaction' => $transaction,
            ]);
        }

        if (!empty($this->spreadsheetId) && file_exists($this->resolvePath($this->serviceAccountPath))) {
            return $this->appendViaServiceAccount([
                [
                    (string) ($transaction['id'] ?? ''),
                    (string) ($transaction['transaction_date'] ?? ''),
                    (string) ($transaction['type'] ?? ''),
                    (string) ($transaction['category_name'] ?? '-'),
                    (float) ($transaction['amount'] ?? 0),
                    (string) ($transaction['description'] ?? '-'),
                    (string) ($transaction['updated_at'] ?? date('Y-m-d H:i:s')),
                ]
            ]);
        }

        return [
            'success' => false,
            'message' => 'Google Sheets belum dikonfigurasi. Masukkan URL Web App Google Apps Script atau Service Account di menu Pengaturan.',
        ];
    }

    /**
     * Hapus 1 transaksi dari Google Sheets berdasarkan ID
     */
    public function deleteTransaction(int|string $id): array
    {
        if (!empty($this->webhookUrl)) {
            return $this->sendWebhook([
                'action' => 'delete',
                'id' => $id,
            ]);
        }

        return [
            'success' => false,
            'message' => 'Hapus baris spesifik memerlukan mode Google Apps Script atau sinkronisasi penuh (Sync All).',
        ];
    }

    /**
     * Sinkronisasi seluruh data transaksi dari Database Laravel ke Google Sheets
     */
    public function syncAllTransactions(array $transactions): array
    {
        if (!empty($this->webhookUrl)) {
            return $this->sendWebhook([
                'action' => 'sync_all',
                'transactions' => $transactions,
            ]);
        }

        if (!empty($this->spreadsheetId) && file_exists($this->resolvePath($this->serviceAccountPath))) {
            $rows = [
                ['ID', 'Tanggal', 'Tipe', 'Kategori', 'Nominal (Rp)', 'Catatan', 'Waktu Input']
            ];
            foreach ($transactions as $t) {
                $rows[] = [
                    (string) ($t['id'] ?? ''),
                    (string) ($t['transaction_date'] ?? ''),
                    (string) ($t['type'] ?? ''),
                    (string) ($t['category_name'] ?? '-'),
                    (float) ($t['amount'] ?? 0),
                    (string) ($t['description'] ?? '-'),
                    (string) ($t['updated_at'] ?? date('Y-m-d H:i:s')),
                ];
            }
            return $this->overwriteSheetViaServiceAccount($rows);
        }

        return [
            'success' => false,
            'message' => 'Google Sheets belum dikonfigurasi. Silakan isi URL Webhook Apps Script di Pengaturan.',
        ];
    }

    protected function sendWebhook(array $payload): array
    {
        $ch = curl_init(trim($this->webhookUrl));
        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => json_encode($payload),
            CURLOPT_HTTPHEADER => ['Content-Type: text/plain;charset=utf-8', 'Accept: application/json'],
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_FOLLOWLOCATION => false,
            CURLOPT_HEADER => true,
            CURLOPT_TIMEOUT => 15,
            CURLOPT_SSL_VERIFYPEER => false,
        ]);

        $rawResponse = curl_exec($ch);
        $error = curl_error($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $headerSize = curl_getinfo($ch, CURLINFO_HEADER_SIZE);
        $redirectUrl = curl_getinfo($ch, CURLINFO_REDIRECT_URL);
        curl_close($ch);

        if ($rawResponse === false) {
            return ['success' => false, 'message' => 'Gagal menghubungi Google Apps Script: ' . $error];
        }

        $headers = substr($rawResponse, 0, $headerSize);
        $body = substr($rawResponse, $headerSize);

        if (empty($redirectUrl) && preg_match('/^Location:\s*(.+)$/mi', $headers, $m)) {
            $redirectUrl = trim($m[1]);
        }

        if ($httpCode >= 300 && $httpCode < 400 && !empty($redirectUrl)) {
            if (str_contains($redirectUrl, 'accounts.google.com')) {
                return [
                    'success' => false,
                    'message' => 'Akses ditolak Google. Pastikan di Apps Script bagian "Who has access" dipilih "Anyone (Siapa saja)".',
                ];
            }

            $chGet = curl_init($redirectUrl);
            curl_setopt_array($chGet, [
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_FOLLOWLOCATION => true,
                CURLOPT_TIMEOUT => 15,
                CURLOPT_SSL_VERIFYPEER => false,
            ]);
            $body = (string) curl_exec($chGet);
            $httpCode = curl_getinfo($chGet, CURLINFO_HTTP_CODE);
            curl_close($chGet);
        }

        $decoded = json_decode($body, true);
        if (is_array($decoded) && isset($decoded['success'])) {
            return $decoded;
        }

        if ($httpCode >= 200 && $httpCode < 400) {
            return ['success' => true, 'message' => 'Data berhasil disinkronkan ke Google Sheets!'];
        }

        return ['success' => false, 'message' => "Gagal sinkron ke Google Sheets (HTTP $httpCode)"];
    }

    protected function appendViaServiceAccount(array $rows): array
    {
        $token = $this->getServiceAccountAccessToken();
        if (!$token) {
            return ['success' => false, 'message' => 'Gagal membuat akses token dari Service Account JSON'];
        }

        $range = urlencode($this->tabName . '!A:G');
        $url = "https://sheets.googleapis.com/v4/spreadsheets/{$this->spreadsheetId}/values/{$range}:append?valueInputOption=USER_ENTERED";

        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => json_encode(['values' => $rows]),
            CURLOPT_HTTPHEADER => [
                'Content-Type: application/json',
                'Authorization: Bearer ' . $token,
            ],
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 15,
            CURLOPT_SSL_VERIFYPEER => false,
        ]);

        $res = curl_exec($ch);
        $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($code >= 200 && $code < 300) {
            return ['success' => true, 'message' => 'Berhasil ditambahkan via Google Sheets API v4'];
        }

        return ['success' => false, 'message' => 'Gagal menulis ke Google Sheets API v4: ' . $res];
    }

    protected function overwriteSheetViaServiceAccount(array $rows): array
    {
        $token = $this->getServiceAccountAccessToken();
        if (!$token) {
            return ['success' => false, 'message' => 'Gagal membuat akses token dari Service Account JSON'];
        }

        $range = urlencode($this->tabName . '!A1:G5000');
        $clearUrl = "https://sheets.googleapis.com/v4/spreadsheets/{$this->spreadsheetId}/values/{$range}:clear";

        $ch = curl_init($clearUrl);
        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => '{}',
            CURLOPT_HTTPHEADER => [
                'Content-Type: application/json',
                'Authorization: Bearer ' . $token,
            ],
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_SSL_VERIFYPEER => false,
        ]);
        curl_exec($ch);
        curl_close($ch);

        $updateRange = urlencode($this->tabName . '!A1');
        $updateUrl = "https://sheets.googleapis.com/v4/spreadsheets/{$this->spreadsheetId}/values/{$updateRange}?valueInputOption=USER_ENTERED";

        $ch2 = curl_init($updateUrl);
        curl_setopt_array($ch2, [
            CURLOPT_CUSTOMREQUEST => 'PUT',
            CURLOPT_POSTFIELDS => json_encode(['values' => $rows]),
            CURLOPT_HTTPHEADER => [
                'Content-Type: application/json',
                'Authorization: Bearer ' . $token,
            ],
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_SSL_VERIFYPEER => false,
        ]);
        $res = curl_exec($ch2);
        $code = curl_getinfo($ch2, CURLINFO_HTTP_CODE);
        curl_close($ch2);

        if ($code >= 200 && $code < 300) {
            return ['success' => true, 'message' => 'Seluruh transaksi berhasil disinkronkan via Google Sheets API v4'];
        }

        return ['success' => false, 'message' => 'Gagal sinkronisasi via API v4: ' . $res];
    }

    protected function getServiceAccountAccessToken(): ?string
    {
        $path = $this->resolvePath($this->serviceAccountPath);
        if (!file_exists($path)) {
            return null;
        }

        $creds = json_decode(file_get_contents($path), true);
        if (empty($creds['client_email']) || empty($creds['private_key'])) {
            return null;
        }

        $now = time();
        $header = $this->base64UrlEncode(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
        $claim = $this->base64UrlEncode(json_encode([
            'iss' => $creds['client_email'],
            'scope' => 'https://www.googleapis.com/auth/spreadsheets',
            'aud' => 'https://oauth2.googleapis.com/token',
            'exp' => $now + 3600,
            'iat' => $now,
        ]));

        $signatureInput = $header . '.' . $claim;
        $signature = '';
        if (!openssl_sign($signatureInput, $signature, $creds['private_key'], 'SHA256')) {
            return null;
        }

        $jwt = $signatureInput . '.' . $this->base64UrlEncode($signature);

        $ch = curl_init('https://oauth2.googleapis.com/token');
        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => http_build_query([
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $jwt,
            ]),
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_SSL_VERIFYPEER => false,
        ]);

        $res = curl_exec($ch);
        curl_close($ch);

        $data = json_decode((string) $res, true);
        return $data['access_token'] ?? null;
    }

    protected function base64UrlEncode(string $data): string
    {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }

    protected function resolvePath(string $path): string
    {
        if (function_exists('base_path')) {
            return base_path($path);
        }
        return dirname(__DIR__, 2) . DIRECTORY_SEPARATOR . $path;
    }
}
