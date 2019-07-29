import MonacoEditor from 'react-monaco-editor';
import * as React from 'react';
import {Spin} from 'antd';
import rest from 'src/api/rest';

const options = {
  selectOnLineNumbers: true
};

export default class ConfigEditor extends React.Component{
  state = {
    code: '',
    loading: true,
  }

  async componentDidMount(){
    const res = await rest.get(
      '/admin/config',
    );
    this.setState(() => ({
      code: res.data,
      loading: false,
    }))
  }

  render(){
    const { code, loading } = this.state
    return (<div>
      <Spin spinning={loading}>
        <MonacoEditor
          height={"800"}
          language={"yaml"}
          options={options}
          value={code}
          onChange={(v) => this.setState(() => ({code: v}))}
        />
      </Spin>
    </div>)
  }
}
