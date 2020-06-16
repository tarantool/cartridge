// @flow
import * as React from 'react'
import { connect } from 'react-redux'
import type { State } from '../store/rootReducer'
import { Panel } from './Panel'
import { css, cx } from 'emotion'
import styled from 'react-emotion'
import {
  Button,
  ConfirmModal,
  CopyToClipboard,
  Markdown,
  Modal,
  PopupBody,
  PopupFooter,
  Tabbed,
  Text
} from '@tarantool.io/ui-kit'
import { validateTarantoolUri } from '../misc/decomposeTarantoolUri';

const uriDecompose = uri => {
  const [credentials, server] = uri.split('@')
  const [user, password] = credentials.split(':')
  const [host, port] = server.split(':')
  return {
    user,
    password,
    host,
    port
  }
}

const connectInfoMap: {[key: string]: {markdown: string, decomposed: boolean}} = {
  Python: {
    markdown: `
## Connect to Tarantool Cartridge using [python client](https://github.com/tarantool/tarantool-python)

**Install** *tarantool* package using *pip3*:

\`\`\`bash
pip3 install tarantool
\`\`\`

**Create** a file *example.py* with this code to get started:

\`\`\`python
from tarantool import Connection
c = Connection(
    ":host:", 
    :port:,
    user=':user:', 
    password=':password:'
)
result = c.insert("customer", (332, 'John Smith'))
space = c.space("customer")
results = space.select()
print(results)
\`\`\`

**Run** the script:

\`\`\`bash
python3 example.py
\`\`\`
`,
    decomposed: true
  },
  PHP: {
    markdown: `
## Connect to Tarantool Cartridge using [PHP client](https://github.com/tarantool-php/client)

**Install** *messagepack* and *tarantool client* using *composer*:

\`\`\`bash
composer require rybakit/msgpack
composer require tarantool/client
\`\`\`

**Create** a file *example.php* with this code to get started:

\`\`\`php
<?php

use Tarantool\\Client\\Client;
use Tarantool\\Client\\Schema\\Criteria;

require __DIR__ . '/vendor/autoload.php';

$client = Client::fromDsn('tcp://:demo_uri:');
$space = $client->getSpace('customer');
$space->insert([222, 'Michael Bryan']);
$result = $space->select(Criteria::key([222]));

print_r($result);
\`\`\`

**Run** the script:
  
\`\`\`bash
php example.php
\`\`\`
`,
    decomposed: false
  }
}

const styles = {
  wrap: css`
    display: flex;
    justify-content: space-between;
    align-items: center;
  `,
  btn: css`
    flex-shrink: 0;
    margin-left: 16px;
  `,
  copyBtn: css`
    flex-shrink: 0;
    margin-left: 8px;
  `
}

const DemoContext = styled(Panel)`
  margin: 24px 16px;
  padding: 16px;
  display: flex;
`

const Bold = styled.span`
  font-weight: bold;
  white-space: pre;
`

const MainContent = styled.div`
  flex-shrink: 1;
  display: flex;
  align-items: center;
`

const formatUri = (text: string, uri: string) => text.replace(':demo_uri:', uri)
const formatDecomposeUri = (text: string, uri: string) => {
  const { user, password, host, port } = uriDecompose(uri)
  return text.replace(':port:', port)
    .replace(':user:', user)
    .replace(':password:', password)
    .replace(':host:', host)
}

type DemoInfoProps = {
  className: ?string,
  uri: ?string
}

type DemoInfoState = {
  isShowReset: boolean,
  isShowConnectInfo: boolean,
}

class DemoInfo extends React.Component<DemoInfoProps, DemoInfoState> {
  state = {
    isShowReset: false,
    isShowConnectInfo: false
  }

  showResetModal = () => {
    this.setState(() => ({ isShowReset: true }))
  }
  hideResetModal = () => {
    this.setState(() => ({ isShowReset: false }))
  }
  showConnectInfo = () => {
    this.setState(() => ({ isShowConnectInfo: true }))
  }
  hideConnectInfo = () => {
    this.setState(() => ({ isShowConnectInfo: false }))
  }

  makeReset = () => {
    window.location.href = '/?flush_session=1'
  }

  render() {
    const { className, uri } = this.props
    const { isShowReset, isShowConnectInfo } = this.state
    if (!uri)
      return null

    const isValidUri = validateTarantoolUri(uri)

    if (!isValidUri)
      return null

    const tabStyles = css`padding: 24px 0 0;`;

    const tabs = []

    try {

      for (const lang in connectInfoMap) {
        const { markdown, decomposed } = connectInfoMap[lang]
        tabs.push({
          label: lang,
          content: <PopupBody className={tabStyles}>
            <Markdown text={decomposed ? formatDecomposeUri(markdown, uri) : formatUri(markdown, uri)}/>
          </PopupBody>
        })
      }
    } catch(e) {

    }

    return <React.Fragment>
      {
        isShowReset &&
        <ConfirmModal
          title='Reset configuration'
          visible={isShowReset}
          onCancel={this.hideResetModal}
          onConfirm={this.makeReset}
          confirmText={'Reset'}
        >
          <Text tag='p'>Do you really want to reset your settings?</Text>
          <Text tag='p'>This action will result in data loss.</Text>
        </ConfirmModal>
      }
      {
        isShowConnectInfo &&
        <Modal
          visible={isShowConnectInfo}
          title={'Connect info'}
          onClose={this.hideConnectInfo}
          className='meta-test__DemoInfo_modal'
          thinBorders
          wide
        >
          <Tabbed tabs={tabs}/>
          <PopupFooter
            controls={[
              <Button text='Close' onClick={this.hideConnectInfo}/>
            ]}
          />
        </Modal>
      }
      <DemoContext className={cx(styles.wrap, 'meta-test__DemoInfo', className)}>
        <MainContent>
          <Text>
            {'Your demo server is created. Temporary address of you server: '}
            <Bold>
              {uri}
              <CopyToClipboard className={styles.copyBtn} content={uri} intent='iconic' size='s' />
            </Bold>
          </Text>
          <Button className={styles.btn} text='How to connect?' intent='iconic' onClick={this.showConnectInfo} />
        </MainContent>
        <Button className={styles.btn} text='Reset configuration' intent='iconic' onClick={this.showResetModal} />
      </DemoContext>
    </React.Fragment>
  }
}


export default connect(({ app: { clusterSelf } }: State) => {
  return {
    uri: clusterSelf && clusterSelf.demo_uri || null
  }
})(DemoInfo)
