/**
 * 环境变量构建器
 * 参考 android-openclaw EnvironmentBuilder.kt
 */
import { common } from '@kit.AbilityKit';

/**
 * 环境变量构建器
 */
export class EnvironmentBuilder {

  /**
   * 构建完整的环境变量
   */
  static build(context: common.Context): Map<string, string> {
    const filesDir = context.filesDir;
    const prefix = `${filesDir}/usr`;
    const home = `${filesDir}/home`;
    const tmp = `${filesDir}/tmp`;

    const env = new Map<string, string>();

    // 核心路径
    env.set('PREFIX', prefix);
    env.set('HOME', home);
    env.set('TMPDIR', tmp);
    env.set('PATH', `${home}/.openclaw-android/node/bin:${home}/.local/bin:${prefix}/bin:${prefix}/bin/applets`);
    env.set('LD_LIBRARY_PATH', `${prefix}/lib`);

    // Termux 兼容
    env.set('TERMUX__PREFIX', prefix);
    env.set('TERMUX_PREFIX', prefix);
    env.set('TERMUX__ROOTFS', filesDir);

    // apt/dpkg
    env.set('APT_CONFIG', `${prefix}/etc/apt/apt.conf`);
    env.set('DPKG_ADMINDIR', `${prefix}/var/lib/dpkg`);
    env.set('DPKG_ROOT', prefix);

    // SSL
    env.set('SSL_CERT_FILE', `${prefix}/etc/tls/cert.pem`);
    env.set('CURL_CA_BUNDLE', `${prefix}/etc/tls/cert.pem`);
    env.set('GIT_SSL_CAINFO', `${prefix}/etc/tls/cert.pem`);

    // Git
    env.set('GIT_CONFIG_NOSYSTEM', '1');
    env.set('GIT_EXEC_PATH', `${prefix}/libexec/git-core`);
    env.set('GIT_TEMPLATE_DIR', `${prefix}/share/git-core/templates`);

    // 语言和终端
    env.set('LANG', 'en_US.UTF-8');
    env.set('TERM', 'xterm-256color');

    // OpenClaw 平台
    env.set('OA_GLIBC', '1');
    env.set('CONTAINER', '1');
    env.set('CLAWDHUB_WORKDIR', `${home}/.openclaw/workspace`);

    return env;
  }

  /**
   * 获取 PATH 环境变量
   */
  static getPath(context: common.Context): string {
    const env = EnvironmentBuilder.build(context);
    return env.get('PATH') || '';
  }

  /**
   * 获取 HOME 环境变量
   */
  static getHome(context: common.Context): string {
    const env = EnvironmentBuilder.build(context);
    return env.get('HOME') || context.filesDir;
  }

  /**
   * 获取 PREFIX 环境变量
   */
  static getPrefix(context: common.Context): string {
    const env = EnvironmentBuilder.build(context);
    return env.get('PREFIX') || `${context.filesDir}/usr`;
  }
}

export default EnvironmentBuilder;
