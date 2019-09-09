import React from 'react';
import * as control from './control';

type FSItemProps = {
    onClick: () => void;
    contents: string;
};

type FSItemState = {};

class FSItem extends React.Component<FSItemProps, FSItemState> {
    get contents() {
        return this.props.contents;
    }

    render() {
        return (
            <button onClick={this.props.onClick}
                    className="fs-browser-item">
                {this.props.contents}
            </button>
        );
    }
}

type FSBrowserProps = {
    root: string,
    onTraverseUp: (path: string[]) => void,
    onTraverseDown: (path: string[]) => void,
    onExpandChild: (child: string, fullChildPath: string) => void,
    browsePath: string[],
};
type FSBrowserState = {};

export class FSBrowser extends React.Component<FSBrowserProps, FSBrowserState> {
    get browsePathString() {
        return control.bfsSetup.path.join(...this.props.browsePath);
    }

    get browsingRoot() {
        return control.bfsSetup.path.join(...this.props.browsePath) ===
            this.props.root;
    }

    static compareFSItemPair =
        (a: [string, FSItem],
         b: [string, FSItem]): any => {
        if (a[0] < b[0]) {
            return -1;
        } else if (a[0] > b[0]) {
            return 1;
        } else {
            return 0;
        }
    };

    traverseUp = (): void => {
        const newPath = this.props.browsePath.slice();
        newPath.pop();

        this.props.onTraverseUp(newPath);
    };

    traverseDown = (childDirectory: string): void => {
        const newPath = this.props.browsePath.slice();
        newPath.push(childDirectory);

        this.props.onTraverseDown(newPath);
    };

    expandChild = (child: string): void => {
        const fullChildPath =
            control.bfsSetup.path.join(this.browsePathString, child);
        const stats = control.fs.statSync(fullChildPath);

        if (stats.isDirectory()) {
            this.traverseDown(child);
        } else if (stats.isFile()) {
            this.props.onExpandChild(child, fullChildPath);
        }
    }

    createFSItemPair = (filePath: string): [string, any] => {
        return [
            filePath,
            <FSItem key={filePath}
                    onClick={() => this.expandChild(filePath)}
                    contents={filePath}/>
        ];
    };

    render() {
        return (
            <div className="menu-content">
                {!this.browsingRoot && (
                    <button className="fs-browser-item"
                            onClick={this.traverseUp}>
                        ..
                    </button>
                )}
                {
                    control.fs
                           .readdirSync(this.browsePathString)
                           .map(this.createFSItemPair)
                           .sort(FSBrowser.compareFSItemPair)
                           .map((x: [string, FSItem]) => x[1])
                }
            </div>
        );
    }
}