import { hilog } from '@kit.PerformanceAnalysisKit';
import { describe, it, expect } from '@ohos/hypium';
import { TraccarConstants } from '../../../main/ets/common/constants/TraccarConstants';

/**
 * 端侧冒烟测试：只验证与设备弱相关的常量契约不漂移。
 * 真正需要 Web 内核/权限的用例（桥接、下载、生物识别）在没有签名证书的
 * 本地环境跑不了，放在手工验收清单里（见 BUILD.md）。
 */
export default function abilityTest() {
  describe('traccarManagerAbilityTest', () => {
    it('defaultServerIsDemoInstance', 0, () => {
      hilog.info(0x0000, 'TraccarManager', '%{public}s', 'ability test begin');
      expect(TraccarConstants.DEFAULT_SERVER_URL).assertEqual('https://demo.traccar.org');
    });

    it('keepsUpstreamPreferenceKeys', 0, () => {
      // 'url' 与 'token' 必须与上游 Flutter 版本一致，否则从旧版升级后服务器地址会丢。
      expect(TraccarConstants.PREF_KEY_SERVER_URL).assertEqual('url');
      expect(TraccarConstants.SECRET_KEY_TOKEN).assertEqual('token');
      expect(TraccarConstants.DEEP_LINK_SCHEME).assertEqual('org.traccar.manager');
    });
  });
}
