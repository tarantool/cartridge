import React from 'react';

import './LoginForm.css';

class LoginForm extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      loginFormData: {
        email: '',
        password: '',
      },
    };
  }

  render() {
    const { submitMessage } = this.props;
    const { loginFormData } = this.state;

    return (
      <div className="LoginForm-outer">
        <div className="LoginForm-inner">
          <form>
            <fieldset>
              <div className="form-group row">
              <label
                className="col-sm-3 col-form-label"
                htmlFor="app-email"
              >
                Email
              </label>
              <div className="col-sm-9">
                <input
                  id="app-email"
                  type="text"
                  name="email"
                  className="form-control"
                  value={loginFormData.email}
                  onChange={this.handleInputFieldChange} />
              </div>
            </div>
              <div className="form-group row">
                <label
                  className="col-sm-3 col-form-label"
                  htmlFor="app-password"
                >
                  Password
                </label>
                <div className="col-sm-9">
                  <input
                    id="app-password"
                    type="password"
                    name="password"
                    className="form-control"
                    value={loginFormData.password}
                    onChange={this.handleInputFieldChange} />
                </div>
              </div>
              <div className="LoginForm-buttons">
                <button
                  type="submit"
                  className="btn btn-success"
                  onClick={this.handleSubmitClick}
                >
                  Submit
                </button>
                <div className="LoginForm-submitMessage">
                  {submitMessage}
                </div>
              </div>
            </fieldset>
          </form>
        </div>
      </div>
    );
  }

  handleInputFieldChange = event => {
    const { loginFormData } = this.state;
    const { target } = event;
    this.setState({ loginFormData: { ...loginFormData, [target.name]: target.value } });
  };

  handleSubmitClick = event => {
    event.preventDefault();
    const { login } = this.props;
    const { loginFormData } = this.state;
    login(loginFormData);
  };
}

export default LoginForm;
