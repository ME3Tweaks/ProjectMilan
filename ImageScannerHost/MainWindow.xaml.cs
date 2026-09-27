using System.ComponentModel;
using System.IO;
using System.IO.Pipes;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using Microsoft.Win32;

namespace ImageScannerHost
{
    /// <summary>
    /// Slit-scan image scanner. Receives overhead game captures via a named pipe
    /// and composites vertical center slits into a wide panoramic image.
    /// </summary>
    public partial class MainWindow : Window
    {
        private const string PipeName = "slitscanhost";
        private const int MaxCaptures = 75000;
        private const int TileWidthPixels = 4096;

        // Image / capture parameters received from the client
        private int _imageWidth;
        private int _imageHeight;
        private float _stepGameUnits;
        private int _captureCount;

        // Configurable slit width (pixels)
        private int _slitWidth = 8;

        // Tile-based scan storage (each byte[] is one tile of BGRA pixel data).
        // Splitting across tiles avoids the ~2 GB single-object limit.
        private List<byte[]>? _scanTiles;
        private int _totalScanWidth;
        private int _currentSlitIndex;

        // Game-coordinate bounding box
        private int _minGameX = int.MaxValue, _maxGameX = int.MinValue;
        private int _minGameY = int.MaxValue, _maxGameY = int.MinValue;
        private double _topLeftX, _topLeftY, _bottomRightX, _bottomRightY;

        // Preview bitmap and timer
        private WriteableBitmap? _previewBitmap;
        private DispatcherTimer? _previewTimer;
        private int _previewWidth, _previewHeight;
        private double _previewScale = 1.0;
        private int _lastPreviewSlitIndex;

        // Listening state
        private bool _isListening;
        private bool _captureComplete;
        private CancellationTokenSource? _cts;

        public MainWindow()
        {
            InitializeComponent();
        }

        protected override void OnClosing(CancelEventArgs e)
        {
            _cts?.Cancel();
            _previewTimer?.Stop();
            base.OnClosing(e);
        }

        // ── Listening ───────────────────────────────────────────────────────

        private void StartListening_Click(object sender, RoutedEventArgs e)
        {
            if (_isListening) return;

            if (!int.TryParse(SlitWidthBox.Text, out int slitWidth) || slitWidth < 1)
            {
                MessageBox.Show("Slit width must be a positive integer.",
                    "Invalid Input", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            _slitWidth = slitWidth;
            _isListening = true;
            _captureComplete = false;
            _currentSlitIndex = 0;
            _lastPreviewSlitIndex = 0;
            _scanTiles = null;

            SlitWidthBox.IsEnabled = false;
            StartListeningBtn.IsEnabled = false;
            SaveFullBtn.IsEnabled = false;
            SaveTilesBtn.IsEnabled = false;
            CaptureProgress.Value = 0;

            _cts = new CancellationTokenSource();
            var token = _cts.Token;

            _previewTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
            _previewTimer.Tick += PreviewTimer_Tick;
            _previewTimer.Start();

            Task.Run(() => ListenOnPipe(token), token);

            StatusText.Text = $"Listening on pipe '{PipeName}'...";
        }

        private void ListenOnPipe(CancellationToken token)
        {
            try
            {
                using var server = new NamedPipeServerStream(PipeName, PipeDirection.In, 1,
                    PipeTransmissionMode.Byte);

                Dispatcher.Invoke(() => StatusText.Text = "Waiting for connection...");
                server.WaitForConnection();
                Dispatcher.Invoke(() => StatusText.Text = "Connected. Awaiting capture commands...");

                using var reader = new BinaryReader(server);

                while (!token.IsCancellationRequested && server.IsConnected)
                {
                    byte command;
                    try
                    {
                        command = reader.ReadByte();
                    }
                    catch (EndOfStreamException)
                    {
                        break;
                    }

                    switch (command)
                    {
                        case 1: ReadStartCapture(reader); break;
                        case 2: ReadCaptureCount(reader); break;
                        case 3: ReadCapture(reader); break;
                        case 4: FinishCapture(); return;
                    }
                }

                // Client disconnected without CAPTURE_END
                if (!_captureComplete && Volatile.Read(ref _currentSlitIndex) > 0)
                    FinishCapture();
            }
            catch (Exception ex) when (!token.IsCancellationRequested)
            {
                Dispatcher.Invoke(() =>
                {
                    StatusText.Text = $"Error: {ex.Message}";
                    ResetControls();
                });
            }
        }

        // ── Protocol handlers ───────────────────────────────────────────────

        private void ReadStartCapture(BinaryReader reader)
        {
            _imageWidth = reader.ReadInt32();
            _imageHeight = reader.ReadInt32();
            _stepGameUnits = reader.ReadSingle();
            _captureComplete = false;
            _currentSlitIndex = 0;
            _lastPreviewSlitIndex = 0;
            _scanTiles = null;
            _minGameX = int.MaxValue; _maxGameX = int.MinValue;
            _minGameY = int.MaxValue; _maxGameY = int.MinValue;

            Dispatcher.Invoke(() =>
                StatusText.Text = $"Capture started: {_imageWidth}x{_imageHeight}, step {_stepGameUnits:F1} units");
        }

        private void ReadCaptureCount(BinaryReader reader)
        {
            _captureCount = Math.Min(reader.ReadInt32(), MaxCaptures);
            _totalScanWidth = _captureCount * _slitWidth;

            int tileCount = (_totalScanWidth + TileWidthPixels - 1) / TileWidthPixels;
            _scanTiles = new List<byte[]>(tileCount);
            for (int i = 0; i < tileCount; i++)
            {
                int tw = Math.Min(TileWidthPixels, _totalScanWidth - i * TileWidthPixels);
                _scanTiles.Add(new byte[tw * _imageHeight * 3]);
            }

            Dispatcher.Invoke(() =>
            {
                InitializePreview();
                CaptureProgress.Maximum = _captureCount;
                StatusText.Text = $"Expecting {_captureCount} captures ({_totalScanWidth}x{_imageHeight})";
            });
        }

        private void ReadCapture(BinaryReader reader)
        {
            int cameraX = reader.ReadInt32();
            int cameraY = reader.ReadInt32();
            int byteCount = reader.ReadInt32();

            byte[] imageData = new byte[byteCount];
            reader.BaseStream.ReadExactly(imageData);

            int idx = Volatile.Read(ref _currentSlitIndex);
            if (idx >= _captureCount || _scanTiles == null)
                return;

            // Update coordinate bounding box
            if (cameraX < _minGameX) _minGameX = cameraX;
            if (cameraX > _maxGameX) _maxGameX = cameraX;
            if (cameraY < _minGameY) _minGameY = cameraY;
            if (cameraY > _maxGameY) _maxGameY = cameraY;

            // Extract the center vertical slit and copy into tile storage
            int slitStart = (_imageWidth - _slitWidth) / 2;
            int gx0 = idx * _slitWidth;

            for (int c = 0; c < _slitWidth; c++)
            {
                int srcCol = slitStart + c;
                int gx = gx0 + c;
                int ti = gx / TileWidthPixels;
                int lx = gx % TileWidthPixels;

                if (ti >= _scanTiles.Count) break;

                byte[] tile = _scanTiles[ti];
                int tw = GetTileWidth(ti);

                for (int y = 0; y < _imageHeight; y++)
                {
                    int s = (y * _imageWidth + srcCol) * 4;
                    int d = (y * tw + lx) * 3;

                    if (s + 3 < imageData.Length && d + 2 < tile.Length)
                    {
                        tile[d]     = imageData[s];
                        tile[d + 1] = imageData[s + 1];
                        tile[d + 2] = imageData[s + 2];
                        // alpha discarded — always 255 in captures
                    }
                }
            }

            // Write index after tile data to ensure ordering for preview reads
            Volatile.Write(ref _currentSlitIndex, idx + 1);
        }

        private void FinishCapture()
        {
            _captureComplete = true;

            double uPerPx = _slitWidth > 0 ? (double)_stepGameUnits / _slitWidth : 1.0;
            double halfSlitU = (_slitWidth / 2.0) * uPerPx;
            double halfHeightU = (_imageHeight / 2.0) * uPerPx;

            _topLeftX = _minGameX - halfSlitU;
            _topLeftY = _minGameY - halfHeightU;
            _bottomRightX = _maxGameX + halfSlitU;
            _bottomRightY = _maxGameY + halfHeightU;

            Dispatcher.Invoke(() =>
            {
                _previewTimer?.Stop();
                int total = Volatile.Read(ref _currentSlitIndex);
                UpdatePreview(total);
                CaptureProgress.Value = total;
                StatusText.Text = $"Complete: {total} slits. " +
                    $"Bounds ({_topLeftX:F1}, {_topLeftY:F1}) -> ({_bottomRightX:F1}, {_bottomRightY:F1})";
                SaveFullBtn.IsEnabled = true;
                SaveTilesBtn.IsEnabled = true;
                ResetControls();
            });
        }

        private void ResetControls()
        {
            _isListening = false;
            StartListeningBtn.IsEnabled = true;
            SlitWidthBox.IsEnabled = true;
        }

        private int GetTileWidth(int tileIndex) =>
            Math.Min(TileWidthPixels, _totalScanWidth - tileIndex * TileWidthPixels);

        // ── Preview ─────────────────────────────────────────────────────────

        private void InitializePreview()
        {
            const int maxW = 4096, maxH = 2048;
            if (_totalScanWidth <= 0 || _imageHeight <= 0) return;

            _previewScale = Math.Min(1.0,
                Math.Min((double)maxW / _totalScanWidth, (double)maxH / _imageHeight));

            _previewWidth = Math.Max(1, (int)(_totalScanWidth * _previewScale));
            _previewHeight = Math.Max(1, (int)(_imageHeight * _previewScale));

            _previewBitmap = new WriteableBitmap(
                _previewWidth, _previewHeight, 96, 96, PixelFormats.Bgra32, null);
            PreviewImage.Source = _previewBitmap;
            _lastPreviewSlitIndex = 0;
        }

        private void PreviewTimer_Tick(object? sender, EventArgs e)
        {
            int cur = Volatile.Read(ref _currentSlitIndex);
            CaptureProgress.Value = cur;
            StatusText.Text = $"Captured {cur}/{_captureCount}";
            if (cur > _lastPreviewSlitIndex) UpdatePreview(cur);
        }

        /// <summary>
        /// Incrementally renders only the newly captured columns into the preview bitmap.
        /// </summary>
        private void UpdatePreview(int upTo)
        {
            if (_previewBitmap == null || _scanTiles == null || upTo == 0) return;

            int fromGx = _lastPreviewSlitIndex * _slitWidth;
            int toGx = upTo * _slitWidth;
            int pxFrom = (int)(fromGx * _previewScale);
            int pxTo = Math.Min(_previewWidth, (int)Math.Ceiling(toGx * _previewScale));

            if (pxFrom >= pxTo) return;

            int w = pxTo - pxFrom;
            byte[] buf = new byte[w * _previewHeight * 4];

            for (int py = 0; py < _previewHeight; py++)
            {
                int sy = Math.Min((int)(py / _previewScale), _imageHeight - 1);
                for (int px = 0; px < w; px++)
                {
                    int sx = Math.Min((int)((pxFrom + px) / _previewScale), _totalScanWidth - 1);
                    int ti = sx / TileWidthPixels, lx = sx % TileWidthPixels;
                    if (ti >= _scanTiles.Count) continue;

                    byte[] tile = _scanTiles[ti];
                    int tw = GetTileWidth(ti);
                    int sOff = (sy * tw + lx) * 3;
                    if (sOff + 2 >= tile.Length) continue;

                    int dOff = (py * w + px) * 4;
                    buf[dOff]     = tile[sOff];
                    buf[dOff + 1] = tile[sOff + 1];
                    buf[dOff + 2] = tile[sOff + 2];
                    buf[dOff + 3] = 255;
                }
            }

            _previewBitmap.WritePixels(new Int32Rect(pxFrom, 0, w, _previewHeight), buf, w * 4, 0);
            _lastPreviewSlitIndex = upTo;
        }

        // ── Save ────────────────────────────────────────────────────────────

        private void SaveFull_Click(object sender, RoutedEventArgs e)
        {
            if (_scanTiles == null || _currentSlitIndex == 0) return;

            var dlg = new SaveFileDialog
            {
                Filter = "BMP Image|*.bmp",
                DefaultExt = ".bmp",
                FileName = "slitscan_full"
            };

            if (dlg.ShowDialog() != true) return;

            SaveFullBmp(dlg.FileName);
            SaveCoordinateInfo(Path.ChangeExtension(dlg.FileName, ".txt"));
            MessageBox.Show("Full image saved.", "Save Complete",
                MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private void SaveTiles_Click(object sender, RoutedEventArgs e)
        {
            if (_scanTiles == null || _currentSlitIndex == 0) return;

            var dlg = new OpenFolderDialog { Title = "Select output folder for tiles" };
            if (dlg.ShowDialog() != true) return;

            SaveTilePngs(dlg.FolderName);
            SaveCoordinateInfo(Path.Combine(dlg.FolderName, "coordinates.txt"));
            MessageBox.Show("Tiles saved.", "Save Complete",
                MessageBoxButton.OK, MessageBoxImage.Information);
        }

        /// <summary>
        /// Writes the composite scan as a top-down 32-bit BMP.
        /// Rows are streamed so total file size can exceed 2 GB safely.
        /// </summary>
        private void SaveFullBmp(string path)
        {
            int width = _currentSlitIndex * _slitWidth;
            int height = _imageHeight;
            int rowStride = (width * 3 + 3) & ~3; // 24-bit BMP rows are padded to 4-byte alignment
            long pixelBytes = (long)rowStride * height;
            long fileSize = 54 + pixelBytes;

            using var fs = new FileStream(path, FileMode.Create, FileAccess.Write, FileShare.None, 65536);
            using var bw = new BinaryWriter(fs);

            // BITMAPFILEHEADER (14 bytes)
            bw.Write((ushort)0x4D42);
            bw.Write((uint)(fileSize <= uint.MaxValue ? fileSize : 0));
            bw.Write((ushort)0);
            bw.Write((ushort)0);
            bw.Write((uint)54);

            // BITMAPINFOHEADER (40 bytes)
            bw.Write((uint)40);
            bw.Write(width);
            bw.Write(-height);      // negative = top-down row order
            bw.Write((ushort)1);
            bw.Write((ushort)24);   // 24-bit BGR
            bw.Write((uint)0);      // BI_RGB
            bw.Write((uint)0);
            bw.Write(0);
            bw.Write(0);
            bw.Write((uint)0);
            bw.Write((uint)0);

            // Stream pixel rows from tile storage; buffer is zero-initialised so padding bytes stay zero
            byte[] row = new byte[rowStride];
            for (int y = 0; y < height; y++)
            {
                int written = 0;
                for (int ti = 0; ti < _scanTiles!.Count && written < width; ti++)
                {
                    int tw = GetTileWidth(ti);
                    int cols = Math.Min(tw, width - written);
                    Buffer.BlockCopy(_scanTiles[ti], y * tw * 3, row, written * 3, cols * 3);
                    written += cols;
                }
                bw.Write(row, 0, rowStride);
            }
        }

        /// <summary>
        /// Saves each tile as an individual PNG file.
        /// </summary>
        private void SaveTilePngs(string folder)
        {
            if (_scanTiles == null) return;

            int actualWidth = _currentSlitIndex * _slitWidth;
            int tileCount = (actualWidth + TileWidthPixels - 1) / TileWidthPixels;

            for (int i = 0; i < tileCount && i < _scanTiles.Count; i++)
            {
                int saveTw = Math.Min(TileWidthPixels, actualWidth - i * TileWidthPixels);
                if (saveTw <= 0) break;

                int dataTw = GetTileWidth(i);
                var bmp = new WriteableBitmap(saveTw, _imageHeight, 96, 96, PixelFormats.Bgr24, null);
                bmp.WritePixels(new Int32Rect(0, 0, saveTw, _imageHeight),
                    _scanTiles[i], dataTw * 3, 0);

                string tilePath = Path.Combine(folder, $"tile_{i:D4}.png");
                using var fs = new FileStream(tilePath, FileMode.Create);
                var enc = new PngBitmapEncoder();
                enc.Frames.Add(BitmapFrame.Create(bmp));
                enc.Save(fs);
            }
        }

        private void SaveCoordinateInfo(string path)
        {
            double uPerPx = _slitWidth > 0 ? (double)_stepGameUnits / _slitWidth : 1.0;
            int actualW = _currentSlitIndex * _slitWidth;
            int tileCount = (actualW + TileWidthPixels - 1) / TileWidthPixels;

            using var sw = new StreamWriter(path);
            sw.WriteLine($"ScanWidth={actualW}");
            sw.WriteLine($"ScanHeight={_imageHeight}");
            sw.WriteLine($"SlitWidth={_slitWidth}");
            sw.WriteLine($"CaptureCount={_currentSlitIndex}");
            sw.WriteLine($"StepGameUnits={_stepGameUnits:F4}");
            sw.WriteLine($"GameUnitsPerPixel={uPerPx:F6}");
            sw.WriteLine($"TopLeftX={_topLeftX:F4}");
            sw.WriteLine($"TopLeftY={_topLeftY:F4}");
            sw.WriteLine($"BottomRightX={_bottomRightX:F4}");
            sw.WriteLine($"BottomRightY={_bottomRightY:F4}");
            sw.WriteLine($"TilePixelWidth={TileWidthPixels}");
            sw.WriteLine($"TileCount={tileCount}");
        }
    }
}