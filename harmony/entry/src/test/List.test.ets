import uriModelTest from './UriModel.test';
import bridgeScriptTest from './BridgeScript.test';
import contractTest from './Contract.test';

export default function testsuite() {
  uriModelTest();
  bridgeScriptTest();
  contractTest();
}
