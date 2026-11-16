import { webview } from '@kit.ArkWeb';
import { cert } from '@kit.DeviceCertificateKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { Utils } from '../common/Utils';

export class SslInfoResult {
  ok: boolean = false;
  error: string = '';
  subject: string = '';
  issuer: string = '';
  notBefore: number = 0;
  notAfter: number = 0;
  sigAlg: string = '';
  serial: string = '';
  sha256: string = '';
  sans: string[] = [];
  chainSize: number = 0;
  daysLeft: number = 0;

  summary(): string {
    const lines: string[] = [];
    lines.push('颁发给：' + this.subject);
    lines.push('颁发者：' + this.issuer);
    let valid: string = '有效期：' + Utils.formatDate(this.notBefore) + ' 至 ' + Utils.formatDate(this.notAfter);
    if (this.daysLeft >= 0) {
      valid += '（剩余 ' + this.daysLeft.toString() + ' 天）';
    } else {
      valid += '（已过期 ' + (-this.daysLeft).toString() + ' 天）';
    }
    lines.push(valid);
    lines.push('签名算法：' + this.sigAlg);
    const serial: string = this.serial.length > 24 ? this.serial.substring(0, 24) + '…' : this.serial;
    lines.push('序列号：' + serial);
    lines.push('SHA-256 指纹：');
    lines.push(this.sha256);
    if (this.sans.length > 0) {
      const shown: number = Math.min(6, this.sans.length);
      let s: string = '备用域名：';
      for (let i = 0; i < shown; i++) {
        if (i > 0) {
          s += '、';
        }
        s += this.sans[i];
      }
      if (this.sans.length > shown) {
        s += ' 等 ' + this.sans.length.toString() + ' 个';
      }
      lines.push(s);
    }
    lines.push('证书链：' + this.chainSize.toString() + ' 张证书');
    return lines.join('\n');
  }
}

/** 通过 ArkWeb 的 getCertificate 获取当前网站证书并解析 */
export class SslInfo {
  static async fetch(controller: webview.WebviewController): Promise<SslInfoResult> {
    const result: SslInfoResult = new SslInfoResult();
    let chain: cert.X509Cert[] = [];
    try {
      chain = await controller.getCertificate();
    } catch (e) {
      result.error = 'TLS 握手失败或证书不可用';
      return result;
    }
    if (!chain || chain.length === 0) {
      result.error = '服务器未返回证书';
      return result;
    }
    try {
      const c: cert.X509Cert = chain[0];
      const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      result.subject = SslInfo.cnOf(decoder.decodeToString(c.getSubjectName().data));
      result.issuer = SslInfo.cnOf(decoder.decodeToString(c.getIssuerName().data));
      result.notBefore = Utils.parseDateToMillis(c.getNotBeforeTime());
      result.notAfter = Utils.parseDateToMillis(c.getNotAfterTime());
      result.sigAlg = c.getSignatureAlgName();
      result.serial = c.getCertSerialNumber().toString(16).toUpperCase();
      result.chainSize = chain.length;
      result.daysLeft = Math.floor((result.notAfter - Date.now()) / 86400000);
      result.sha256 = await SslInfo.fingerprint(c);
      result.sans = SslInfo.readSans(c);
      result.ok = true;
    } catch (e) {
      result.error = '证书解析失败';
      return result;
    }
    return result;
  }

  private static cnOf(dn: string): string {
    if (!dn) {
      return '';
    }
    const parts: string[] = dn.split(',');
    for (const raw of parts) {
      const part: string = raw.trim();
      if (part.toUpperCase().startsWith('CN=')) {
        return part.substring(3);
      }
    }
    return dn;
  }

  private static async fingerprint(c: cert.X509Cert): Promise<string> {
    try {
      const encoded: cert.EncodingBlob = await c.getEncoded();
      const md: cryptoFramework.Md = cryptoFramework.createMd('SHA256');
      await md.update({ data: encoded.data });
      const digest: cryptoFramework.DataBlob = await md.digest();
      let out: string = '';
      for (let i = 0; i < digest.data.length; i++) {
        if (i > 0) {
          out += ':';
        }
        const b: number = digest.data[i];
        out += (b < 16 ? '0' : '') + b.toString(16).toUpperCase();
      }
      return out;
    } catch (e) {
      return '';
    }
  }

  /** 从 GeneralNames DER 中提取可读的 DNS 名称 */
  private static readSans(c: cert.X509Cert): string[] {
    const names: string[] = [];
    try {
      const data: cert.DataArray = c.getSubjectAltNames();
      for (const blob of data.data) {
        let current: string = '';
        for (let i = 0; i < blob.length; i++) {
          const b: number = blob[i];
          if (b >= 32 && b < 127) {
            current += String.fromCharCode(b);
          } else {
            if (current.length >= 4 && current.includes('.')) {
              names.push(current);
            }
            current = '';
          }
        }
        if (current.length >= 4 && current.includes('.')) {
          names.push(current);
        }
      }
    } catch (e) {
    }
    const unique: string[] = [];
    for (const n of names) {
      if (!unique.includes(n)) {
        unique.push(n);
      }
    }
    return unique.slice(0, 12);
  }
}
