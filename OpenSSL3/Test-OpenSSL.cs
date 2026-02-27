using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Net.Http;
using System.Threading.Tasks;

namespace OpenSslTester
{
    // Helper class to track the result of each URL test
    class UrlStatus 
    { 
        public string Url; 
        public string Error; 
        public bool IsSuccess => Error == null;
    }

    class Program
    {
        private static readonly Stopwatch GlobalTimer = Stopwatch.StartNew();
        private static readonly object _Sync = new object();

        static int Main(string[] args)
        {
            string[] urls = { "https://www.google.com", "https://www.mozilla.org" };
            const int maxRetries = 3;
            const int timeoutSeconds = 30;
            var urlStatusList = new List<UrlStatus>();

            Log("Starting OpenSSL integration test in parallel ...");

            Parallel.ForEach(urls, (url) =>
            {
                var currentStatus = new UrlStatus { Url = url, Error = "Initial state" };
                // Log($"Testing URL: {url}");

                for (int attempt = 1; attempt <= maxRetries; attempt++)
                {
                    // Create a fresh handler and client for every attempt to force a new SSL session
                    using (var handler = new HttpClientHandler())
                    {
                        // Ignore all certificate validation errors as we test the OpenSSL build itself
                        handler.ServerCertificateCustomValidationCallback = (message, cert, chain, errors) => true;

                        using (var client = new HttpClient(handler))
                        {
                            client.Timeout = TimeSpan.FromSeconds(timeoutSeconds);

                            try
                            {
                                Log($"Starting attempt {attempt} of {maxRetries} for {url}...");
                                
                                // Execution in Parallel requires blocking call or Task.Run for async methods
                                var response = client.GetAsync(url).ConfigureAwait(continueOnCapturedContext: false).GetAwaiter().GetResult();

                                Log($"Connection established. HTTP Status: {(int)response.StatusCode}. Attempt {attempt} of {maxRetries} for {url}");
                                
                                currentStatus.Error = null;
                                break; 
                            }
                            catch (Exception ex)
                            {
                                currentStatus.Error = ex.Message;
                                Log($"Connection failed during attempt {attempt} of {maxRetries} for {url}: {ex.Message}", true);
                            }
                        }
                    }

                    if (attempt < maxRetries && !currentStatus.IsSuccess)
                    {
                        Task.Delay(2000).Wait();
                    }
                }

                lock (_Sync)
                {
                    urlStatusList.Add(currentStatus);
                }
            });

            List<string> successfulUrls;
            lock (_Sync)
            {
                successfulUrls = urlStatusList.Where(r => r.IsSuccess).Select(r => r.Url).ToList();
            }

            if (successfulUrls.Any())
            {
                Log($"Test PASSED: OpenSSL successfully established a connection. Success URLs: {string.Join(", ", successfulUrls)}");
                return 0;
            }
            else
            {
                Log("Test FAILED: OpenSSL failed to connect to any host.", true);
                return 1;
            }
        }

        private static void Log(string message, bool error = false)
        {
            TimeSpan ts = GlobalTimer.Elapsed;
            string timestamp = string.Format("{0:00}:{1:00}:{2:00}", ts.Hours, ts.Minutes, ts.Seconds);
            string formattedMessage = $"[{timestamp}] {message}";

            // Console is thread-safe for WriteLine, but locking keeps colors consistent
            lock (_Sync)
            {
                if (error)
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.Error.WriteLine(formattedMessage);
                    Console.ResetColor();
                }
                else
                {
                    Console.WriteLine(formattedMessage);
                }
            }
        }
    }
}
