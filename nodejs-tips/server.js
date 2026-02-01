const app = require('./src/app')
const config = require('./src/config/config.mongodb')

const PORT = config.app.port || 3055

const server = app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`)
})

process.on('SIGINT', () => {
    server.close(() => console.log('Server closed'))
    if (server.closeAllConnections) {
        server.closeAllConnections()
    }
})
