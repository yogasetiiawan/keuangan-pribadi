/**
 * ============================================================================
 * GOOGLE APPS SCRIPT - KONEKTOR OTOMATIS KE LARAVEL (OPSIONAL / CARA MUDAH)
 * ============================================================================
 * Cara Pakai (Tanpa perlu ribet setup Google Cloud Console Service Account):
 * 1. Buka Google Sheets baru di browser Anda.
 * 2. Klik menu Extensions (Ekstensi) -> Apps Script.
 * 3. Hapus semua kode di dalamnya, lalu tempel (paste) seluruh kode ini.
 * 4. Klik tombol "Deploy" (Terapkan) -> "New deployment" (Deployment baru).
 * 5. Pilih jenis: "Web app" (Aplikasi web).
 *    - Execute as: "Me" (Saya)
 *    - Who has access: "Anyone" (Siapa saja)
 * 6. Klik Deploy, salin URL Web App (`https://script.google.com/macros/s/.../exec`),
 *    lalu tempelkan ke file `.env` Laravel pada bagian `GOOGLE_SHEETS_WEBHOOK_URL`
 *    atau langsung melalui menu Pengaturan di aplikasi Flutter!
 */

const SHEET_TRANSAKSI = 'Transaksi';
const SHEET_RINGKASAN = 'Ringkasan';

function setupSheets() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  
  // 1. Buat / Cek Sheet Transaksi
  let sheetTrx = ss.getSheetByName(SHEET_TRANSAKSI);
  if (!sheetTrx) {
    sheetTrx = ss.insertSheet(SHEET_TRANSAKSI);
  }
  if (sheetTrx.getLastRow() === 0) {
    const headers = ['ID', 'Tanggal', 'Tipe', 'Kategori', 'Nominal (Rp)', 'Catatan', 'Waktu Input'];
    sheetTrx.getRange(1, 1, 1, headers.length).setValues([headers]);
    sheetTrx.getRange(1, 1, 1, headers.length)
      .setFontWeight('bold')
      .setBackground('#1E293B')
      .setFontColor('#FFFFFF');
    sheetTrx.setFrozenRows(1);
  }

  // 2. Buat / Cek Sheet Ringkasan
  let sheetSum = ss.getSheetByName(SHEET_RINGKASAN);
  if (!sheetSum) {
    sheetSum = ss.insertSheet(SHEET_RINGKASAN);
  }
  sheetSum.clear();
  sheetSum.getRange('A1:B4').setValues([
    ['Keterangan', 'Total (Rp)'],
    ['Total Pemasukan', '=SUMIF(Transaksi!C:C, "income", Transaksi!E:E)'],
    ['Total Pengeluaran', '=SUMIF(Transaksi!C:C, "expense", Transaksi!E:E)'],
    ['Saldo Akhir', '=B2-B3']
  ]);
  sheetSum.getRange('A1:B1').setFontWeight('bold').setBackground('#0F172A').setFontColor('#FFFFFF');
  sheetSum.getRange('B2:B4').setNumberFormat('#,##0');
  
  return { sheetTrx, sheetSum };
}

function doPost(e) {
  try {
    const payload = JSON.parse(e.postData.contents);
    const action = payload.action || 'upsert';
    const { sheetTrx } = setupSheets();

    if (action === 'sync_all' && Array.isArray(payload.transactions)) {
      // Hapus semua baris data kecuali header
      const lastRow = sheetTrx.getLastRow();
      if (lastRow > 1) {
        sheetTrx.getRange(2, 1, lastRow - 1, 7).clearContent();
      }
      if (payload.transactions.length > 0) {
        const rows = payload.transactions.map(t => [
          t.id,
          t.transaction_date,
          t.type,
          t.category_name || '-',
          Number(t.amount),
          t.description || '-',
          t.updated_at || new Date().toISOString()
        ]);
        sheetTrx.getRange(2, 1, rows.length, 7).setValues(rows);
        sheetTrx.getRange(2, 5, rows.length, 1).setNumberFormat('#,##0');
      }
      return jsonResponse({ success: true, message: 'Semua transaksi berhasil disinkronkan', count: payload.transactions.length });
    }

    if (action === 'upsert' && payload.transaction) {
      const t = payload.transaction;
      const rowData = [
        t.id,
        t.transaction_date,
        t.type,
        t.category_name || '-',
        Number(t.amount),
        t.description || '-',
        t.updated_at || new Date().toISOString()
      ];

      const rowIndex = findRowById(sheetTrx, t.id);
      if (rowIndex > 0) {
        sheetTrx.getRange(rowIndex, 1, 1, 7).setValues([rowData]);
        sheetTrx.getRange(rowIndex, 5).setNumberFormat('#,##0');
      } else {
        sheetTrx.appendRow(rowData);
        const newRow = sheetTrx.getLastRow();
        sheetTrx.getRange(newRow, 5).setNumberFormat('#,##0');
      }
      return jsonResponse({ success: true, message: 'Transaksi berhasil disimpan ke Google Sheet' });
    }

    if (action === 'delete' && payload.id) {
      const rowIndex = findRowById(sheetTrx, payload.id);
      if (rowIndex > 0) {
        sheetTrx.deleteRow(rowIndex);
      }
      return jsonResponse({ success: true, message: 'Transaksi berhasil dihapus dari Google Sheet' });
    }

    return jsonResponse({ success: false, message: 'Action tidak dikenali' });
  } catch (err) {
    return jsonResponse({ success: false, error: err.toString() });
  }
}

function findRowById(sheet, id) {
  const lastRow = sheet.getLastRow();
  if (lastRow < 2) return -1;
  const ids = sheet.getRange(2, 1, lastRow - 1, 1).getValues();
  for (let i = 0; i < ids.length; i++) {
    if (String(ids[i][0]) === String(id)) {
      return i + 2;
    }
  }
  return -1;
}

function jsonResponse(data) {
  return ContentService
    .createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}
