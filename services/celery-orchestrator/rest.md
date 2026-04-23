# REST-интерфейс оркестратора

🚧 AsynchronousTaskInputData записываются в kwargs
   - status progress-таски: если не смогла найти correlationId, то FAILED, в остальных случаях SUCCESS
🚧 AsynchronousTaskFinishData:
   - result записывается в Result той таски, которую находим по correlationId. Если не нашли, тогда это FAILED для finish-таски
   - status - это статус той, которая correlationId, а у самой finish-таски статус failed, если она не смогла найти correlationId, либо success

