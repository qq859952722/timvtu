#! /bin/bash
set -ex
if [[ -z "${VER}" ]]; then
  VER="latest"
fi
echo ${VER}

if [[ -z "${UUID}" ]]; then
  UUID="ffc17112-b755-499d-be9f-91a828bd3197"
fi
echo ${UUID}

if [[ -z "${AlterID}" ]]; then
  AlterID="64"
fi
echo ${AlterID}

if [[ -z "${V2_Path}" ]]; then
  V2_Path="/static"
fi
echo ${V2_Path}

if [[ -z "${V2_QR_Path}" ]]; then
  V2_QR_Path="qr_img"
fi
echo ${V2_QR_Path}

rm -rf /etc/localtime
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
date -R


if [ "$VER" = "latest" ]; then
  V_VER=`wget -qO- "https://api.github.com/repos/v2ray/v2ray-core/releases/latest" | grep 'tag_name' | cut -d\" -f4`
else
  V_VER="v$VER"
fi

mkdir /v2raybin
cd /v2raybin
V2RAY_URL="https://github.com/v2ray/v2ray-core/releases/download/$V_VER/v2ray-linux-64.zip"
echo ${V2RAY_URL}
wget --no-check-certificate -qO 'v2ray.zip' ${V2RAY_URL}
unzip v2ray.zip
rm -rf v2ray.zip


C_VER=`wget -qO- "https://api.github.com/repos/mholt/caddy/releases/latest" | grep 'tag_name' | cut -d\" -f4`
mkdir /caddybin
cd /caddybin
CADDY_URL="https://github.com/mholt/caddy/releases/download/$C_VER/caddy_${C_VER}_linux_amd64.tar.gz"
echo ${CADDY_URL}
wget --no-check-certificate -qO 'caddy.tar.gz' ${CADDY_URL}
tar xvf caddy.tar.gz
rm -rf caddy.tar.gz
chmod +x caddy

cd /wwwroot
tar xvf wwwroot.tar.gz
rm -rf wwwroot.tar.gz

cat <<-EOF > /v2raybin/config.json
{  
   "log": {
    "loglevel": "debug"
  },
  "reverse":{ 
    // 这是 A 的反向代理设置，必须有下面的 bridges 对象
    "bridges":[  
      {  
        "tag":"bridge", // 关于 A 的反向代理标签，在路由中会用到
        "domain":"private.cloud.com" // A 和 B 反向代理通信的域名，可以自己取一个，可以不是自己购买的域名，但必须跟下面 B 中的 reverse 配置的域名一致
      }
    ]
  },
  "inbounds": [
    {
      "port": 3333,
      "protocol": "socks",
      "settings": {
        "auth": "noauth",
        "udp": false,
        "ip": "127.0.0.1",
        "userLevel": 0
      },
      "tag": "in-0",
      "streamSettings": {
        "network": "tcp",
        "security": "none",
        "tcpSettings": {}
      }
    },
    {
        "tag": "in-1",
		"protocol":"vmess",
        "listen":"127.0.0.1",
        "port":2333,
        "settings":{
            "clients":[
                {
                    "id":"${UUID}",
                    "level":1,
                    "alterId":${AlterID}
                }
            ]
        },
        "streamSettings":{
            "network":"ws",
            "wsSettings":{
                "path":"${V2_Path}"
            }
        }
    }
  ],
  "outbounds": [
    {  
      //A连接B的outbound  
      "tag":"tunnel", // A 连接 B 的 outbound 的标签，在路由中会用到
      "protocol":"vmess",
      "settings":{  
        "vnext":[  
          {  
            "address":"${V2RAY_DOM}", // B 地址，IP 或 实际的域名
            "port":${V2RAY_PORT},
            "users":[  
              {  
                "id":"${UUID}",
                "alterId":${AlterID}
              }
            ]
          }
        ]
      },
	  "streamSettings": {
        "network": "mkcp",
        "kcpSettings": {
          "uplinkCapacity": 5,
          "downlinkCapacity": 100,
          "congestion": true,
          "header": {
            "type": "utp"
          }
        }
      }
    },
    // 另一个 outbound，最终连接私有网盘    
    {  
      "protocol":"freedom",
      "settings":{  
      },
      "tag":"out"
    }    
  ],
  "routing":{   
    "rules":[  
      {  
        // 配置 A 主动连接 B 的路由规则
        "type":"field",
        "inboundTag":[  
          "bridge"
        ],
        "domain":[  
          "full:private.cloud.com"
        ],
        "outboundTag":"tunnel"
      },
      {  
        // 反向连接访问私有网盘的规则
        "type":"field",
        "inboundTag":[  
          "bridge"
        ],
        "outboundTag":"out"
      },
      {  
        // 本地socket连接出口
        "type":"field",
        "inboundTag":[  
          "in-0"
        ],
        "outboundTag":"out"
      },
      {  
        // 本地socket连接出口
        "type":"field",
        "inboundTag":[  
          "in-1"
        ],
        "outboundTag":"out"
      }
    ]
  }
}
EOF

echo /v2raybin/config.json
cat /v2raybin/config.json

cat <<-EOF > /caddybin/Caddyfile
http://0.0.0.0:${PORT}
{
	root /wwwroot
	index index.html
	timeouts none
	proxy ${V2_Path} localhost:2333 {
		websocket
		header_upstream -Origin
	}
}
EOF

cat <<-EOF > /v2raybin/vmess.json 
{
    "v": "2",
    "ps": "${AppName}.herokuapp.com",
    "add": "${AppName}.herokuapp.com",
    "port": "443",
    "id": "${UUID}",
    "aid": "${AlterID}",			
    "net": "ws",			
    "type": "none",			
    "host": "",			
    "path": "${V2_Path}",	
    "tls": "tls"
}
EOF

if [ "$AppName" = "no" ]; then
  echo "不生成二维码"
else
  mkdir /wwwroot/${V2_QR_Path}
  vmess="vmess://$(cat /v2raybin/vmess.json | base64 -w 0)" 
  Linkbase64=$(echo -n "${vmess}" | tr -d '\n' | base64 -w 0) 
  echo "${Linkbase64}" | tr -d '\n' > /wwwroot/${V2_QR_Path}/index.html
  echo -n "${vmess}" | qrencode -s 6 -o /wwwroot/${V2_QR_Path}/v2.png
fi
cp /v2raybin/config.json /wwwroot
cd /v2raybin
./v2ray -config config.json &
cd /caddybin
./caddy -conf="Caddyfile"
