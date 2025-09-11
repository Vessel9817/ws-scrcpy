import assert from 'assert';

type Dependency = {
    dependencies?: Record<string, string>;
    devDependencies?: Record<string, string>;
    optionalDependencies?: Record<string, string>;
    engines?: Record<string, string> | string[];
};

type PackageLock = {
    lockfileVersion: number;
    packages: Record<string, Dependency>;
};

/**
 * A key-value pair mapping a package name to its supported Node versions
 */
type PackageNodeSupportInfo = Record<string, string>;

/**
 * Returns the Node support information of the given package's subdependencies
 * @param deps The parsed `package-lock.json` file
 * @param dep The package to inspect
 * @param depType The type of dependency to inspect
 */
function getChildrenNodeSupport(
    deps: PackageLock,
    dep: Dependency,
    depType: 'dependencies' | 'devDependencies' | 'optionalDependencies'
): PackageNodeSupportInfo {
    let versions: PackageNodeSupportInfo = {};

    if (depType in dep) {
        for (const subdepName in dep[depType]) {
            const trueSubdepName = `node_modules/${subdepName}`;
            const includeDev = depType === 'devDependencies';
            const includeOpt = depType === 'optionalDependencies';

            versions = {
                ...versions,
                ...getNodeSupport(deps, trueSubdepName, includeDev, includeOpt)
            };
        }
    }

    return versions;
}

// TODO Memoize
/**
 * Returns the Node support information of the given package and its subdependencies
 * @param deps The parsed `package-lock.json` file
 * @param depName The package name
 * @param includeDev If true, includes devDependencies
 * @param includeOpt If true, includes optionalDependencies
 */
function getNodeSupport(
    deps: PackageLock,
    depName: string,
    includeDev: boolean,
    includeOpt: boolean
): PackageNodeSupportInfo {
    let versions: PackageNodeSupportInfo = {};
    const dep = deps.packages[depName];

    if (dep.engines != null && 'node' in dep.engines) {
        // Getting node version supported by package
        versions[depName] = dep.engines.node;
    }
    else {
        // As a fallback, querying package subdependencies
        versions = {
            ...versions,
            ...getChildrenNodeSupport(deps, dep, 'dependencies'),
            ...(includeDev && getChildrenNodeSupport(deps, dep, 'devDependencies')),
            ...(includeOpt && getChildrenNodeSupport(deps, dep, 'optionalDependencies'))
        };
    }

    return versions;
}

/**
 * Prints the Node support information of this project's (sub)dependencies
 */
function main(): void {
    const deps = require('../../package-lock.json') as PackageLock;

    // Sanity test
    assert.ok(deps.lockfileVersion === 3, `Unknown package-lock.json version: ${deps.lockfileVersion}`);

    const includeDev = true;
    const includeOpt = true;
    const versions = Object.entries(getNodeSupport(deps, '', includeDev, includeOpt))
        .map(([depName, ver]) => `"${ver}": "${depName}"`);

    versions.sort((a, b) => a.localeCompare(b));
    console.log(versions.join('\n'));
}

main();
