<?php
if (!headers_sent() && php_sapi_name() !== 'cli') {
    ob_start(function($buffer) {
        if (stripos($buffer, '</body>') === false) return $buffer;
        
        $module_dir = __DIR__;
        
        $app_name = "My Application";
        $sub_id = "";
        $email = "";
        $buy_link = "https://www.devpanel.com/pricing/";
        $show_buy_now = false;

        $data_file = $module_dir . '/data.json';
        if (file_exists($data_file)) {
            $json_string = file_get_contents($data_file);
            $parsed_data = json_decode($json_string, true); 
            
            if ($parsed_data) {
                $app_name = $parsed_data['appName'] ?? $app_name;
                $sub_id = $parsed_data['subId'] ?? '';
                $email = $parsed_data['email'] ?? '';
                $buy_link = $parsed_data['buyLink'] ?? $buy_link;
                $show_buy_now = $parsed_data['showBuyNow'] ?? false;
            }
        }

        $css_content = file_exists($module_dir . '/alert-bar.css') ? file_get_contents($module_dir . '/alert-bar.css') : '';
        $js_content = file_exists($module_dir . '/alert-bar.js') ? file_get_contents($module_dir . '/alert-bar.js') : '';

        $buy_btn_html = '';
        if ($show_buy_now) {
            $buy_btn_html = '<a href="' . htmlspecialchars($buy_link) . '" class="dp-buy-btn" target="_blank">
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M7 18c-1.1 0-1.99.9-1.99 2S5.9 22 7 22s2-.9 2-2-.9-2-2-2zM1 2v2h2l3.6 7.59-1.35 2.45c-.16.28-.25.61-.25.96 0 1.1.9 2 2 2h12v-2H7.42c-.14 0-.25-.11-.25-.25l.03-.12.9-1.63h7.45c.75 0 1.41-.41 1.75-1.03l3.58-6.49c.08-.14.12-.31.12-.48 0-.55-.45-1-1-1H5.21l-.94-2H1zm16 16c-1.1 0-1.99.9-1.99 2s.89 2 1.99 2 2-.9 2-2-.9-2-2-2z"/></svg>
                Buy Now
            </a>';
        }

        $alert_html = '
        <style>' . $css_content . '</style>
        
        <div id="dp-alert-wrapper" data-nosnippet>
            <div class="dp-top-bar">
                <div class="dp-logo">
                    <img src="https://www.devpanel.com/wp-content/uploads/2025/08/src_logo_devPanel_new_white.png" alt="DevPanel" />
                </div>
                
                <button id="dp-toggle-btn" class="dp-toggle-btn">
                    App Details
                    <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path></svg>
                </button>
                
                ' . $buy_btn_html . '
            </div>
            
            <div id="dp-details-panel" class="dp-details-panel">
                <div class="dp-details-grid">
                    <div class="dp-detail-item">
                        <span class="dp-detail-label">Application</span>
                        <span class="dp-detail-value">' . htmlspecialchars($app_name) . '</span>
                    </div>
                    <div class="dp-detail-item">
                        <span class="dp-detail-label">Submission ID</span>
                        <span class="dp-detail-value">' . htmlspecialchars($sub_id) . '</span>
                    </div>
                    <div class="dp-detail-item">
                        <span class="dp-detail-label">Contact Email</span>
                        <span class="dp-detail-value">' . htmlspecialchars($email) . '</span>
                    </div>
                </div>
            </div>
        </div>
        
        <script>' . $js_content . '</script>
        ';
        
        return preg_replace('/(<body[^>]*>)/i', '$1' . $alert_html, $buffer, 1);
    });
}
