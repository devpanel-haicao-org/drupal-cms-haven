<?php
// Bắt đầu Output Buffering chạy độc lập với Drupal
if (!headers_sent() && php_sapi_name() !== 'cli') {
    ob_start(function($buffer) {
        if (stripos($buffer, '</body>') === false) return $buffer;
        
        // 1. Khai báo dữ liệu mặc định (đề phòng file lỗi hoặc chưa có)
        $app_name = "My Application";
        $buy_link = "https://www.devpanel.com/pricing/";

        // 2. Đọc dữ liệu từ file JSON
        $data_file = __DIR__ . '/alert-bar-data.json';
        if (file_exists($data_file)) {
            $json_string = file_get_contents($data_file);
            $parsed_data = json_decode($json_string, true); // true để parse thành Array
            
            if ($parsed_data) {
                $app_name = $parsed_data['appName'] ?? $app_name;
                $sub_id = $parsed_data['subId'] ?? '';
                $email = $parsed_data['email'] ?? '';
                $buy_link = $parsed_data['buyLink'] ?? $buy_link;
            }
        }
        
        $alert_html = '
        <style>
            body { padding-top: 68px !important; }
            #universal-alert-bar { position: fixed; top: 0; left: 0; width: 100%; height: 68px; background: #000; color: #fff; display: flex; align-items: center; justify-content: space-between; padding: 7px 40px; box-sizing: border-box; z-index: 2147483647; font-family: Arial, sans-serif; }
            #universal-alert-bar .devpanel-logo { width: 150px; height: auto; }
            #universal-alert-bar .devpanel-logo img { object-fit: contain; width: 100%; }
            #universal-alert-bar .devpanel-app-info { font-size: 16px; font-weight: 500; }
            #universal-alert-bar .buy-btn { background: #0033cc; color: #fff; text-decoration: none; padding: 10px 24px; border-radius: 4px; font-weight: bold; }
        </style>
        <div id="universal-alert-bar" data-nosnippet>
            <div class="devpanel-logo"><img src="https://www.devpanel.com/wp-content/uploads/2025/08/src_logo_devPanel_new_white.png" /></div>
            
            <!-- Hiển thị thông tin vào div.devpanel-app-info theo đúng format bạn muốn -->
            <div class="devpanel-app-info">
                App: <strong>' . htmlspecialchars($app_name) . '</strong> | SubmissionID: ' . htmlspecialchars($sub_id) . ' | Email: ' . htmlspecialchars($email) . '
            </div>
            
            <a href="' . htmlspecialchars($buy_link) . '" class="buy-btn" target="_blank">Buy Now</a>
        </div>
        ';
        
        // Chèn HTML ngay sau thẻ mở <body>
        return preg_replace('/(<body[^>]*>)/i', '$1' . $alert_html, $buffer, 1);
    });
}
