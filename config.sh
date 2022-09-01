#!/bin/bash

PM_CONFIG_VERSION=077c09da
SERVER_ADDR="https://192.168.0.167/"
CERTIFICATE="/opt/powermanager/newcerts/C.p12"
CERTIFICATE_PASSWORD="123456"
WIFI_NAME="PowerManager"
WIFI_PASSWORD="12345678"
PLUG_MODEL="B5X"
MQTT_TOPIC="dwd"

# test@gmail.com/google
DAWON_USERID="test@naver.com/naver"

PLUG_IP="192.168.244.1"
PLUG_PORT="5000"
POWER_PLAN="HouseLow"

# generate GUID following command
# cat /proc/sys/kernel/random/uuid
MQTT_CONNECTOR_GUID="964971a1-b95f-4261-9004-bbf8a5274176"
MQTT_CONNECTOR_HOST="127.0.0.1"
MQTT_CONNECTOR_PORT="1883"
MQTT_CONNECTOR_TOPIC="dawon"
MQTT_CONNECTOR_CLIENTID="powermanager"
MQTT_CONNECTOR_ID=""
MQTT_CONNECTOR_PASS=""

DB_PATH=/opt/powermanager/PowerManager.sqlite
CLIENT_CERTIFICATE_PATH=/opt/powermanager/newcerts/C.crt

if [ ! -f PowerManagerConfig ]; then
    wget https://github.com/SeongSikChae/PowerManagerConfig/releases/download/077c09da/Linux-${PM_CONFIG_VERSION}.zip -O tmp.zip
    unzip tmp.zip
    chmod a+x PowerManagerConfig
    rm tmp.zip
fi

read -p "Enter Device Name: " PLUG_NAME

CMD_OUTPUT=$(echo -e "V3\n$WIFI_NAME\n$WIFI_PASSWORD\n$DAWON_USERID\n$PLUG_MODEL\n$MQTT_TOPIC\n\n" | ./PowerManagerConfig \
    --host $PLUG_IP --port $PLUG_PORT --web_server_addr $SERVER_ADDR \
    --clientCertificate $CERTIFICATE --clientCertificatePassword $CERTIFICATE_PASSWORD | tee /dev/tty)

echo $CMD_OUTPUT
VERIFY_DATA=$(echo $CMD_OUTPUT | grep -oE "verify.+")
VERIFY_KEY=$(echo $VERIFY_DATA | awk -F' ' '{print $2}')
VERIFY_MQTT_KEY=$(echo $VERIFY_DATA | awk -F' ' '{print $4}')
PLUG_MAC=$(echo $CMD_OUTPUT | grep -oE "\"mac\":\"[^\"]*" | head -1 | awk -F'"' '{print $4}')
THUMBPRINT=$(openssl x509 -in "$CLIENT_CERTIFICATE_PATH" -noout -fingerprint -sha1 | awk -F'=' '{print $2}' | sed -e 's/://g')

if [ "x$PLUG_NAME" = "x" ]; then
    PLUG_NAME=$PLUG_MAC
fi

echo ""
echo "[DEBUG INFO]"
echo "PLUG_MAC: $PLUG_MAC"
echo "PLUG_NAME: $PLUG_NAME"
echo "VERIFY_KEY: $VERIFY_KEY"
echo "VERIFY_MQTT_KEY: $VERIFY_MQTT_KEY"
echo "THUMBPRINT: $THUMBPRINT"

sqlite3 $DB_PATH "DELETE FROM Device WHERE ID='$PLUG_MAC'"
sqlite3 $DB_PATH "DELETE FROM Device WHERE ID=''"
sqlite3 $DB_PATH "INSERT INTO Device VALUES('$PLUG_MAC', '$PLUG_NAME', '$PLUG_MODEL', '$VERIFY_MQTT_KEY', '$POWER_PLAN', '$MQTT_TOPIC', '0.0', '$MQTT_CONNECTOR_GUID')"

sqlite3 $DB_PATH "DELETE FROM DeviceApi WHERE DeviceId='$PLUG_MAC'"
sqlite3 $DB_PATH "DELETE FROM DeviceApi WHERE DeviceId=''"
sqlite3 $DB_PATH "INSERT INTO DeviceApi VALUES('$DAWON_USERID', '$PLUG_MAC', '$VERIFY_MQTT_KEY', '$VERIFY_KEY')"

sqlite3 $DB_PATH "DELETE FROM UserDevice WHERE DeviceId='$PLUG_MAC'"
sqlite3 $DB_PATH "DELETE FROM UserDevice WHERE DeviceId=''"
sqlite3 $DB_PATH "INSERT INTO UserDevice VALUES('$THUMBPRINT', '$PLUG_MAC')"

sqlite3 $DB_PATH "DELETE FROM MQTTConnector WHERE GUID='$MQTT_CONNECTOR_GUID'"
sqlite3 $DB_PATH "DELETE FROM MQTTConnector WHERE GUID=''"
sqlite3 $DB_PATH "INSERT INTO MQTTConnector VALUES('$MQTT_CONNECTOR_GUID', '$MQTT_CONNECTOR_CLIENTID', 'HAConnector', '$MQTT_CONNECTOR_HOST', '$MQTT_CONNECTOR_PASS', '$MQTT_CONNECTOR_PORT', '0', '$MQTT_CONNECTOR_TOPIC', '$MQTT_CONNECTOR_ID', '0', '1')"

echo -e "\n\n[DEVICE TABLE INFO]"
sqlite3 $DB_PATH "SELECT * FROM Device"

echo -e "\n\n[DEVICE API TABLE INFO]"
sqlite3 $DB_PATH "SELECT * FROM DeviceApi"

echo -e "\n\n[USER DEVICE INFO]"
sqlite3 $DB_PATH "SELECT * FROM UserDevice"

echo -e "\n\n[MQTT CONNECTOR INFO]"
sqlite3 $DB_PATH "SELECT * FROM MQTTConnector"

echo ""
