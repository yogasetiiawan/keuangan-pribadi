/**
 * ============================================================================
 * GOOGLE APPS SCRIPT - KONEKTOR OTOMATIS KE APLIKASI IOS (KEUANGANKU)
 * ============================================================================
 * Sudah disesuaikan dengan Locale Indonesia (pemisah rumus titik koma ';')
 * dan desain Dashboard Eksekutif pada sheet "Ringkasan" & "Transaksi".
 */

const SHEET_TRANSAKSI = 'Transaksi';
const SHEET_RINGKASAN = 'Ringkasan';

function setupSheets() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();

  let sheetTrx = ss.getSheetByName(SHEET_TRANSAKSI);
  if (!sheetTrx) {
    sheetTrx = ss.insertSheet(SHEET_TRANSAKSI);
  }
  if (sheetTrx.getLastRow() === 0) {
    const headers = [
      'ID TRANSAKSI',
      'TANGGAL',
      'TIPE TRANSAKSI',
      'KATEGORI',
      'NOMINAL (RP)',
      'CATATAN / KETERANGAN',
      'WAKTU SINKRONISASI'
    ];
    sheetTrx.getRange(1, 1, 1, headers.length).setValues([headers]);
    sheetTrx.getRange(1, 1, 1, headers.length)
      .setFontWeight('bold')
      .setBackground('#0F172A')
      .setFontColor('#FFFFFF')
      .setHorizontalAlignment('center');
    sheetTrx.setFrozenRows(1);
  }

  let sheetSum = ss.getSheetByName(SHEET_RINGKASAN);
  if (!sheetSum) {
    sheetSum = ss.insertSheet(SHEET_RINGKASAN);
  }

  return { sheetTrx, sheetSum };
}

function doPost(e) {
  try {
    const payload = JSON.parse(e.postData.contents);
    const action = payload.action || 'upsert';
    const { sheetTrx } = setupSheets();

    if (action === 'sync_all' && Array.isArray(payload.transactions)) {
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
        sheetTrx.getRange(2, 5, rows.length, 1).setNumberFormat('"Rp" #,##0');
      }
      return jsonResponse({
        success: true,
        message: 'Semua transaksi berhasil disinkronkan',
        count: payload.transactions.length
      });
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
        sheetTrx.getRange(rowIndex, 5).setNumberFormat('"Rp" #,##0');
      } else {
        sheetTrx.appendRow(rowData);
        const newRow = sheetTrx.getLastRow();
        sheetTrx.getRange(newRow, 5).setNumberFormat('"Rp" #,##0');
      }
      return jsonResponse({
        success: true,
        message: 'Transaksi berhasil disimpan ke Google Sheet'
      });
    }

    if (action === 'delete' && payload.id) {
      const rowIndex = findRowById(sheetTrx, payload.id);
      if (rowIndex > 0) {
        sheetTrx.deleteRow(rowIndex);
      }
      return jsonResponse({
        success: true,
        message: 'Transaksi berhasil dihapus dari Google Sheet'
      });
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
