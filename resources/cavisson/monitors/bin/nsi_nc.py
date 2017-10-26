#!/usr/bin/env python
# Python tool for nc simulator 
# Program: nc.py
# Version: 1.0

import socket
import sys 

"""
  Check for command line validity. If it doesn't meets the specified criteria, 
  reports usage and exits with non zero status 
""" 
def checkAndValidateArgs():
    
    if len(sys.argv) != 4:   #0th arg is the program name itself. 
        usage = \
'''Usage: nc.py <hostname> <port> <message>
Where :
      hostname/IP - the remote host to connect
      port        - the port where the agent is listening
      message     - the message to send over socket.
Eg :
   1. python nc.py localhost 1121 "stats"'''

        print usage
        sys.exit(255)


"""
 This is used to read data from socket. 
 Reads the data in chunk of configurable buffer size
 Param: s, the socket object
 Returns: the data read from the socket 
""" 
def read(s,BUF_SIZE = 1024): 
    msgBufferList = [] # initialize a local empty buffer list 

    data = s.recv(BUF_SIZE)   
    msgBufferList.append(data)

    return "".join(msgBufferList).strip() 

checkAndValidateArgs() 

# Command line parsing 
hostname = sys.argv[1]       # First argument is hostname 
port     = int(sys.argv[2])  # Second is port 
message  = sys.argv[3]       # Third is the client message 
try : 
    clientSocket = socket.socket()              # First create a socket object using factory methods 
    clientSocket.connect((hostname,port))       # Connect to the specified host 
    clientSocket.send(message + "\n")           # Send the message to client and wait for read. Note we are appending '\n'
    recievedMessage = read(clientSocket,4096)   # Read message from client socket connection. Perfectly fine if we dont send
                                                # the buffer size. It picks the DEFAULT_BUF_SIZE = 1024 bytes
    print recievedMessage                       # Print to Stdout all the data
except Exception as e:
    # Print the exception message
    print e 
   
    # Close connection in case of exception and exit from system 
    clientSocket.close() 
    sys.exit(1)

finally: 
    clientSocket.close()  # Always close the connection

