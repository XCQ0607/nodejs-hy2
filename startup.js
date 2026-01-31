#!/usr/bin/env node
const { execSync, spawn } = require('child_process');
const fs = require('fs');

// 判断命令是否存在的辅助函数
function commandExists(cmd) {
    try {
        execSync(`command -v ${cmd}`, { stdio: 'ignore' });
        return true;
    } catch (e) {
        return false;
    }
}

// 尝试安装 bash 和 curl (如果缺失)
function installDependencies() {
    console.log('Checking system dependencies...');

    const hasBash = commandExists('bash');
    const hasCurl = commandExists('curl');

    if (hasBash && hasCurl) {
        console.log('Dependencies found: bash, curl');
        return;
    }

    console.log('Missing dependencies. Attempting to install...');

    try {
        if (commandExists('apk')) {
            // Alpine Linux
            console.log('Detected Alpine Linux. Using apk...');
            execSync('apk update && apk add --no-cache bash curl openssl', { stdio: 'inherit' });
        } else if (commandExists('apt-get')) {
            // Debian/Ubuntu
            console.log('Detected Debian/Ubuntu. Using apt-get...');
            execSync('apt-get update && apt-get install -y bash curl openssl', { stdio: 'inherit' });
        } else if (commandExists('yum')) {
            // CentOS/RHEL
            console.log('Detected CentOS/RHEL. Using yum...');
            execSync('yum install -y bash curl openssl', { stdio: 'inherit' });
        } else {
            console.warn('Unknown package manager. Cannot install dependencies automatically.');
            console.warn('Please ensure "bash" and "curl" are installed manually.');
        }
    } catch (e) {
        console.error('Failed to install dependencies:', e.message);
        // 继续尝试运行，以此为准
    }
}

// 主逻辑
try {
    // 1. 检查并安装依赖
    installDependencies();

    // 2. 赋予脚本执行权限
    if (fs.existsSync('start.sh')) {
        fs.chmodSync('start.sh', 0o755);
    }

    // 3. 启动脚本
    console.log('Starting start.sh...');
    // 使用 spawn 而不是 execSync 以便实时输出日志流，并处理信号
    const child = spawn('bash', ['start.sh'], { stdio: 'inherit' });

    child.on('close', (code) => {
        console.log(`Child process exited with code ${code}`);
        process.exit(code);
    });

    child.on('error', (err) => {
        console.error('Failed to start subprocess:', err);
        // 如果 bash 还是找不到，尝试直接 sh (可能会报错语法，但也比没反应好)
        console.log('Fallback: attempting to run with sh...');
        spawn('sh', ['start.sh'], { stdio: 'inherit' });
    });

} catch (err) {
    console.error('Fatal error:', err);
    process.exit(1);
}
