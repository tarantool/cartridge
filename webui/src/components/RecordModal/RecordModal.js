import React from 'react';

import CodeMirror from 'src/components/CodeMirror';
import Modal from 'src/components/Modal';
import './RecordModal.css';

const beautifyObject = object => JSON.stringify(JSON.parse(object), null, '  ');

class RecordModal extends React.PureComponent {
  render() {
    const { onRequestClose, isLoading, record } = this.props;

    return (
      <Modal
        className="RecordModal-modal"
        title="Object info"
        visible
        width={940}
        onCancel={onRequestClose}
        footer={null}
      >
        {isLoading
          ? null
          : record
            ? (
              <div className="RecordModal-record">
                <div className="RecordModal-recordRow">
                  <span className="RecordModal-pill"><span>ID:</span><span>{record.id}</span></span>
                  <span className="RecordModal-pill"><span>Time:</span><span>{record.time}</span></span>
                  <span className="RecordModal-pill"><span>Status:</span><span>{record.status}</span></span>
                </div>
                <div className="RecordModal-recordRow">
                  <div className="RecordModal-rowHead">
                    Reason:
                  </div>
                  <pre className="ReacordModal-reason">
                    {record.reason}
                  </pre>
                </div>
                <div className="RecordModal-recordRow">
                  <div className="RecordModal-rowHead">
                    Object:
                  </div>
                  <div className="ReacordModal-object">
                    <CodeMirror
                      value={beautifyObject(record.object)}
                      mode="javascript" />
                  </div>
                </div>
              </div>
            )
            : (
              <div className="RecordModal-notFound">
                Object not found
              </div>
            )}
      </Modal>
    );
  }
}

export default RecordModal;
