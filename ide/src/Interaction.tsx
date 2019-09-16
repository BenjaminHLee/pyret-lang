import React from 'react';
import {RenderedValue} from './RenderedValue';

type InteractionProps = {
    name: string;
    value: any;
    setMessage: (newMessage: string) => void;
};

type InteractionState = {};

export class Interaction extends React.Component<InteractionProps, InteractionState> {

    render() {
        if (this.props.name === "$checks" || this.props.name === "$answer") {
            return null;
        }

        return (
            <div className="interaction">
                <pre className="interaction-identifier">
                    {this.props.name} =&nbsp;
                </pre>
                <RenderedValue value={this.props.value} setMessage={this.props.setMessage}></RenderedValue>
            </div>
        )
    };
}
