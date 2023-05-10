#!/bin/bash

# Check if the required parameters are provided
if [ "$#" -ne 12 ]; then
  echo "Usage: $0 --name <name> --from <from_email> --to <to_email> --password <email_password> --server <smtp_server> --port <smtp_port>"
  exit 1
fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --name)
      name="$2"
      shift
      shift
      ;;
    --from)
      from_email="$2"
      shift
      shift
      ;;
    --to)
      to_email="$2"
      shift
      shift
      ;;
    --password)
      email_password="$2"
      shift
      shift
      ;;
    --server)
      smtp_server="$2"
      shift
      shift
      ;;
    --port)
      smtp_port="$2"
      shift
      shift
      ;;
    *)
      echo "Unknown parameter: $1"
      exit 1
      ;;
  esac
done

# List of services to check
services=("bacula-fd" "bacula-sd" "bacula-director" "ssh")

# Email settings
email_subject="$name - server report - $(hostname)"

# Temporary file to store the report
temp_file="/tmp/server_report.txt"

# Functions
get_info() {

  public_ip=$(curl -s ifconfig.me)
  echo -e "Public IP: $public_ip" >> "$temp_file"

  my_hostname=$(hostname)
  echo -e "Hostname: $my_hostname" >> "$temp_file"
  dmi_info=$(dmidecode -s system-manufacturer)
  echo -e "DMI information: $dmi_info" >> "$temp_file"

  my_ip=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d'/' -f1 | head -n 1)
  echo -e "IP Address: $my_ip" >> "$temp_file"

  echo -e "System Load: $(uptime)" >> "$temp_file"
  echo -e "Memory Usage: $(free -m)" >> "$temp_file"

  
  if [ -e "/usr/sbin/megacli" ]; then
    echo -e "\n====== MegaCLI info" >> "$temp_file"
    megacli=`/usr/sbin/megacli -CfgDsply -aALL -nolog |grep '^State'`
    echo "$megacli" >> "$temp_file"
  else
    echo "\nNo MegaCLI information provided" >> "$temp_file"
  fi

  if [ -e "/proc/mdstat" ]; then
    echo -e "\n====== /proc/mdstat " >> "$temp_file"
    mdstat=`cat /proc/mdstat`
    echo "$mdstat" >> "$temp_file"
  else
    echo "\nNo /proc/mdstat information provided" >> "$temp_file"
  fi

  echo -e "\n====== System services" >> "$temp_file"
  for service in "${services[@]}"; do
    status=$(systemctl is-active "$service")
    echo "Service: $service - Status: $status" >> "$temp_file"
  done

  echo -e "\n====== Disk free space" >> "$temp_file"
  df -h >> "$temp_file"


  if [ -e "/usr/sbin/pvesm" ]; then
    echo -e "\n====== pvesm status: " >> "$temp_file"
    /usr/sbin/pvesm status >> "$temp_file"
  else
    echo -e "\nNo pvesm status provided" >> "$temp_file"
  fi

  if [ -e "/usr/sbin/bconsole" ]; then
    echo -e "\n====== Bconsole log: " >> "$temp_file"
    echo -e "\nlist jobs" | bconsole | tail -n40 >> "$temp_file"
  else
    echo "\nNo bconsole information provided" >> "$temp_file"
  fi

}

send_email() {
  email_body=$(cat "$temp_file")
  curl -n --ssl-reqd \
    -u "$from_email:$email_password" \
    --mail-from "$from_email" \
    --mail-rcpt "$to_email" \
    --url "smtp://$smtp_server:$smtp_port" \
    -T - \
    --insecure <<-EOF
From: $from_email
To: $to_email
Subject: $email_subject
Content-Type: text/plain; charset=UTF-8

$email_body
EOF
}

# Main
echo "Server Report - $(date)" > "$temp_file"
echo "======================" >> "$temp_file"
echo "" >> "$temp_file"

echo "====== Server information" >> "$temp_file"
get_info
echo "" >> "$temp_file"

send_email

# Clean up
rm "$temp_file"
