#!/usr/bin/env python

import smtplib
import email.mime.text
import platform
import subprocess
import sys
import os
import notify_conf

if notify_conf.send_mail == "1":
  from_email = notify_conf.from_email
  to_emails = [notify_conf.to_email]

  msg_subject = "UPS Notification " + os.environ.get("NOTIFYTYPE","Email")

  msg_text = "Auto Notification\n"+subprocess.Popen(['/opt/nut/bin/upsc', notify_conf.name], stdout=subprocess.PIPE).communicate()[0]

  msg = email.mime.text.MIMEText(msg_text)
  msg['Subject'] = msg_subject
  msg['From'] = from_email
  msg['To'] = ", ".join(to_emails)
  s = smtplib.SMTP(notify_conf.smtp_server)
  s.sendmail(from_email, to_emails, msg.as_string())
  s.quit()
