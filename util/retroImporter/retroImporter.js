// Retrieve
var MongoClient = require('mongodb').MongoClient;
var util = require('util');

var preconditions = true;

if(process.env.QUERY_TITLE === null || process.env.QUERY_TITLE === undefined)
{
         console.log('ERROR: QUERY_TITLE environment variable not set.');
}
else
{
	console.log('QUERY_TITLE: ' + process.env.QUERY_TITLE);
}


if(process.env.RETRO_QUERY_TITLE === null || process.env.RETRO_QUERY_TITLE === undefined)
{
         console.log('ERROR: RETRO_QUERY_TITLE environment variable not set.');
}
else
{
	console.log('RETRO_QUERY_TITLE: ' + process.env.RETRO_QUERY_TITLE);
}
// Connect to the db
MongoClient.connect('mongodb://hubdb:27017/query_composer_development', function(err, db) {
  if(err) { return console.dir(err); }

  db.collection('queries', null,
    function(err, queriesCollection)
    {
      if(err) { throw err; }

      //fetch the retro query excution
      //****************************************************************************
      queriesCollection.find({title:process.env.RETRO_QUERY_TITLE}).toArray(
        function(err, retroQueries)
        {
          if(err) { throw err; }

          if(retroQueries.length != 1)
          {
            throw new Error('Not one and only one retro query: ' + process.env.RETRO_QUERY_TITLE);
          }

          var retroQuery = retroQueries[0];

          if(retroQuery.executions.length != 1)
          {
            throw new Error('Not one and only one execution for retro query: ' + process.env.RETRO_QUERY_TITLE);
          }

          retroQuery.executions = retroQuery.executions.sort(
            function(a,b)
            {
              return a.time > b.time ? 1 : b.time > a.time ? -1 : 0;
            }
          );

          var retroQueryExecution = retroQuery.executions[0];

          //****************************************************************************

          //fetch query executions
          //****************************************************************************
          var queries = queriesCollection.find({title:process.env.QUERY_TITLE}).toArray(
            function(err, queries)
            {
              if(err) { throw err; }

              if(queries.length != 1)
              {
                throw new Error('Not one and only one query: ' + process.env.QUERY_TITLE);
              }

              var query = queries[0];

              var queryExecutions = query.executions;
              //****************************************************************************

              //fetch retro retroResults
              //****************************************************************************
              var retroResults = retroQueryExecution.aggregate_result;
              //****************************************************************************

              //build simulated executions
              //****************************************************************************
              var simulatedExecutions = {};

              for( var key in retroResults)
              {
                if( !retroResults.hasOwnProperty(key))
                {
                  continue;
                }

                var execution = JSON.parse(key);

                var date = execution.date/1000;//convert to seconds
                var simulatedExecution;

                if( !simulatedExecutions[date] )
                {
                  var aggregate_result = {};
                  var ar_key;

                  if(execution.value === 'numerator')
                  {
                    ar_key = 'numerator_' + execution.pid;
                    aggregate_result[ar_key] = retroResults[key];
                  }
                  else if(execution.value === 'denominator')
                  {
                    ar_key = 'denominator_' + execution.pid;
                    aggregate_result[ar_key] = retroResults[key];
                  }
                  else {
                    throw new Error('key did not have value in ["numerator", "denominator"]');
                  }

                  simulatedExecution = {'_id':retroQueryExecution._id,
                                            'aggregate_result':aggregate_result,
                                            'notification':null,
                                            'time':date
                                            };

                  simulatedExecutions[date] = simulatedExecution;
                }
                else
                {
                  simulatedExecution = simulatedExecutions[date];
	          console.log("simulatedExecution:")
		  console.log(simulatedExecution);
	          console.log("execution:")
	          console.log(execution);
                  if(!simulatedExecution)
                  {
                    throw new Error('simulatedExecution evaluted to false');
                  }
	          
		  var FIELD = 0;
		  var PID = 1;

		  function getPIDMatch(simulatedExecution, execution) 
		  {
			var keys = Object.keys(simulatedExecution.aggregate_result);


			for( var key in keys)
			{
				if(!keys.hasOwnProperty(key))
				{	
					continue;
				}


				var attributes = keys[key].split('_');

				var pid = attributes[PID];
				//var field_test = attributes[FIELD];

				if(execution.pid === pid)
				{
		
					return attributes;
				}

				console.log("execution.pid: "+ execution.pid);
				console.log("pid: "+ pid);
			}
			return null;
		    
		  }
		  	
		  var pidMatch = getPIDMatch(simulatedExecution, execution);

		  if(pidMatch !== null)
                  {

		    console.log("pidMatch: "+ pidMatch);		    
		    console.log("execution.value: "+ execution.value);		    

		    if(execution.value==='denominator')
		    {
                    	simulatedExecution.aggregate_result['denominator_' + execution.pid] = retroResults[key];
		    }
		    else if(execution.value === 'numerator')
		    {
                    	simulatedExecution.aggregate_result['numerator_' + execution.pid] = retroResults[key];
		    }
                    else
                    {
		    	console.log(simulatedExecutions[date]);
                    	throw new Error("ERROR: no match for date: " + date);
                    }
		  }
		  else
		  {
			simulatedExecution.aggregate_result[execution.value + '_' + execution.pid] = retroResults[key];
		  }
		

                  simulatedExecution.aggregate_result.simulated = true;
                }
              }
              //****************************************************************************

              //add the simulated executions to the execution List
              //****************************************************************************
              for( var se in simulatedExecutions)
              {
                if( !simulatedExecutions.hasOwnProperty(se))
                {
                  continue;
                }
		
                queryExecutions.push( simulatedExecutions[se] );
              }
              //****************************************************************************

              //update the query with the retro results
              //****************************************************************************
	      
              queriesCollection.updateOne({title:process.env.QUERY_TITLE}, {$set:{executions:queryExecutions}}, {upsert:true},
                  function(err, result)
                  {
                    if(err)
                    {
                      throw new Error(err);
                    }
		    
		    db.close(
			function(err, result)
			{
				if(err)
				{
					console.log('ERROR: closing db - ' + error);
				}
				else
				{
					console.log('SUCCESS');
				}
			});
                  });

              //****************************************************************************
            });

        });
    }
  );
});
