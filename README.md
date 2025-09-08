# MQTT API Web Server on Windows Server

## 📖 專案介紹
此專案將 **MQTT API Server** 部署於 **Windows Server**，提供 IoT 資料的後端服務。  
透過伺服器環境，實現跨裝置存取與更穩定的 MQTT 資料轉換，並結合前端 Web 介面，方便即時監控。

## 🛠️ 技術堆疊
- 平台：Windows Server  
- 通訊：MQTT 協議  
- 後端：Dart API (需安裝 Flutter 環境)  
- 前端：Flutter Web (支援 RWD 響應式設計)  
- 部署：Apache (Web 架站)

## ✨ 功能特色
- 即時將 MQTT 訊息轉換為 API 輸出  
- 支援多裝置同時監控與資料交換  
- Web 前端支援 **RWD 響應式設計**，可依照不同螢幕自動調整版面  
- 伺服器端可設定 **固定 IP**，確保穩定連線  
- 可於 Apache 上架設 Web 界面，提供使用者瀏覽與操作  

## 🚀 使用方式
1. 安裝並設定 Flutter 環境  
2. 設定 MQTT API 的固定 IP  
3. 將 Web 專案部署於 Apache 伺服器  
4. 啟動 Windows Server 上的後端 API 服務  

## 📝 開發心得
在此專案中，我學會了如何在 **伺服器端環境** 部署並維護 IoT API。  
同時實作了前端 RWD 設計，並結合 Apache 架站，提升了系統穩定性與跨裝置使用體驗。
