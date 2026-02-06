import os
import socket
import yagmail
import argparse
import warnings
warnings.filterwarnings("ignore")

domain_host = {
    "qq.com": "smtp.qq.com",
    "bosc.ac.cn": "smtp.qiye.aliyun.com",
    "ict.ac.cn": "mail.cstnet.cn",
    "ucas.ac.cn": "mail.cstnet.cn",
}

def inform(res, content, email, password, host):
    hostname = socket.gethostname()
    index = hostname + ":" + os.path.basename(os.path.abspath(os.path.dirname(os.getcwd())))
    indexpath = hostname + ":" + os.getcwd()

    if res == 0:
        subject = f"[OK] {index}"
        contents = f"{hostname} 服务器中程序执行完毕\n执行目录 {indexpath}"
    elif res == "0":
        subject = f"[SUCC] {index}"
        contents =  f"{hostname} 服务器中程序执行成功\n执行目录 {indexpath}"
    else:
        subject = f"[FAIL] {index}"
        contents =  f"{hostname} 服务器中程序执行出错\n执行目录 {indexpath}"

    if content != "":
        contents += f"\n执行内容 {content}"

    yag = yagmail.SMTP(user=email, host=host, password=password)
    res = yag.send(email, subject, contents)
    yag.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Auto Email Alert Arguments")
    parser.add_argument('--res', '-r', help="excute result for email contents", default=0)
    parser.add_argument('--content', help="email content", default="")
    args = parser.parse_args()

    email = os.environ.get('MY_EMAIL')
    password = os.environ.get('MY_EMAIL_PWD')

    if email is not None and password is not None:
        domain = email.split("@")[-1]
        inform(args.res, args.content, email, password, host=domain_host[domain])
