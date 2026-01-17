<%@ Page Language="C#" %>
<html>
<head runat="server">
    <title>ASP.NET</title>
    <script runat="server">
        protected string GetOsName()
        {
            string osName = "Windows";
            Microsoft.Win32.RegistryKey subKey = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows NT\CurrentVersion", false);
            using(subKey)
            if (subKey != null)
            {
                 object value = subKey.GetValue("ProductName");
                 if (value != null) osName = value.ToString();
            }

            return osName;
        }
    </script>
</head>
<body>
<h1>OS <%= GetOsName() %> Build <%= Environment.OSVersion.Version %></h1>
<h2>Runtime: <%= System.Environment.Version %></h2>
<h3>Now: <%= DateTime.Now %></h3>
<h4>Powered By IIS</h4>
</body>
</html>

